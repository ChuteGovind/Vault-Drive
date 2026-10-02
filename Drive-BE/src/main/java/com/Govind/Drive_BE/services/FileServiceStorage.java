package com.Govind.Drive_BE.services;

import com.Govind.Drive_BE.entity.FileEntity;
import com.Govind.Drive_BE.repo.FileRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class FileServiceStorage {
    private static final long STORAGE_LIMIT = 1024L * 1024L * 1024L;

    @Value("${file.upload-dir}")
    private String uploadDir;

    private final FileRepository fileRepository;

    public FileServiceStorage(FileRepository fileRepository) {
        this.fileRepository = fileRepository;
    }

    public String saveFile(MultipartFile file, Long parentFolderId, String ownerId) {
        if (ownerId == null || ownerId.isBlank()) throw new IllegalArgumentException("Owner id is required");
        if (file == null || file.isEmpty()) throw new IllegalArgumentException("File is empty");
        if (file.getSize() > STORAGE_LIMIT) throw new IllegalArgumentException("File reached the 1 GB storage limit");

        long used = getUsedStorage(ownerId);
        if (used + file.getSize() > STORAGE_LIMIT) {
            throw new IllegalArgumentException("1 GB storage limit exceeded. Remaining: " + (STORAGE_LIMIT - used) + " bytes");
        }

        String original = file.getOriginalFilename();
        if (original == null || original.isBlank()) throw new IllegalArgumentException("Invalid file name");

        Path rootPath = Paths.get(uploadDir).toAbsolutePath().normalize();
        String safeOwner = ownerId.replaceAll("[^a-zA-Z0-9._-]", "_");
        Path uploadPath = rootPath.resolve(safeOwner).normalize();
        if (!uploadPath.startsWith(rootPath)) throw new IllegalArgumentException("Invalid owner");
        Path filePath = null;
        try {
            Files.createDirectories(uploadPath);

            String safeName = original.replaceAll("[\\\\/:*?\"<>|]", "_");

            String storedName = java.util.UUID.randomUUID() + "_" + safeName;

            filePath = uploadPath.resolve(storedName);

            Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);

            LocalDateTime now = LocalDateTime.now();
            FileEntity entity = new FileEntity();
            entity.setName(original);
            entity.setPath(filePath.toString());
            entity.setSize(file.getSize());
            entity.setType(resolveType(original, file.getContentType()));
            entity.setParentFolderId(parentFolderId);
            entity.setCreatedAt(now);
            entity.setUpdatedAt(now);
            entity.setDeleted(false);
            entity.setOwnerId(ownerId);
            fileRepository.save(entity);
            return "File uploaded successfully";
        } catch (IOException e) {
            if (filePath != null) try { Files.deleteIfExists(filePath); } catch (IOException ignored) {}
            throw new RuntimeException("Failed to upload file", e);
        }
    }

    public List<FileEntity> getFilesInFolder(Long parentFolderId, String ownerId, boolean trash, String search) {
        if (search != null && !search.isBlank() && !trash) {
            return fileRepository.findByOwnerIdAndDeletedFalseAndNameContainingIgnoreCaseOrderByCreatedAtDesc(ownerId, search.trim());
        }
        if (parentFolderId == null) {
            return fileRepository.findByOwnerIdAndDeletedOrderByCreatedAtDesc(ownerId, trash);
        }
        return fileRepository.findByOwnerIdAndParentFolderIdAndDeletedOrderByCreatedAtDesc(ownerId, parentFolderId, trash);
    }

    public FileEntity getFileById(long id, String ownerId) {
        FileEntity file = fileRepository.findById(id).orElseThrow(() -> new RuntimeException("File not found"));
        if (!ownerId.equals(file.getOwnerId())) throw new RuntimeException("File not found");
        return file;
    }

    public void moveToTrash(long id, String ownerId) {
        FileEntity file = getFileById(id, ownerId);
        file.setDeleted(true);
        file.setUpdatedAt(LocalDateTime.now());
        fileRepository.save(file);
    }

    public void restore(long id, String ownerId) {
        FileEntity file = getFileById(id, ownerId);
        file.setDeleted(false);
        file.setUpdatedAt(LocalDateTime.now());
        fileRepository.save(file);
    }

    public void permanentDelete(long id, String ownerId) {
        FileEntity file = getFileById(id, ownerId);
        try { Files.deleteIfExists(Paths.get(file.getPath())); } catch (IOException e) {
            throw new RuntimeException("Unable to delete physical file", e);
        }
        fileRepository.delete(file);
    }

    public void rename(long id, String newName, String ownerId) {
        if (newName == null || newName.isBlank()) throw new IllegalArgumentException("File name is required");
        FileEntity file = getFileById(id, ownerId);
        String clean = newName.trim();
        // Keep the physical stored filename stable; rename only metadata.
        file.setName(clean);
        file.setUpdatedAt(LocalDateTime.now());
        fileRepository.save(file);
    }

    public long getUsedStorage(String ownerId) {
        Long value = fileRepository.sumSizeByOwnerIdAndDeletedFalse(ownerId);
        return value == null ? 0L : value;
    }

    public long getStorageLimit() { return STORAGE_LIMIT; }

    public void deleteAllFilesForOwner(String ownerId) {
        List<FileEntity> files = fileRepository.findByOwnerId(ownerId);
        for (FileEntity file : files) {
            try { Files.deleteIfExists(Paths.get(file.getPath())); } catch (IOException ignored) {}
        }
        fileRepository.deleteAll(files);
        try {
            Path ownerDir = Paths.get(uploadDir).toAbsolutePath().normalize()
                    .resolve(ownerId.replaceAll("[^a-zA-Z0-9._-]", "_"));
            if (Files.exists(ownerDir)) Files.walk(ownerDir).sorted(java.util.Comparator.reverseOrder()).forEach(path -> {
                try { Files.deleteIfExists(path); } catch (IOException ignored) {}
            });
        } catch (IOException ignored) {}
    }

    private String resolveType(String name, String contentType) {
        if (contentType != null && !contentType.isBlank()) return contentType;
        String lower = name.toLowerCase();
        if (lower.endsWith(".pdf")) return "application/pdf";
        if (lower.endsWith(".txt")) return "text/plain";
        if (lower.endsWith(".png")) return "image/png";
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
        if (lower.endsWith(".mp4")) return "video/mp4";
        return "application/octet-stream";
    }
}
