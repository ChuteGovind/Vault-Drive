package com.Govind.Drive_BE.controller;

import com.Govind.Drive_BE.entity.FileEntity;
import com.Govind.Drive_BE.services.FileServiceStorage;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.*;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.file.Paths;
import java.util.*;

@RestController
@RequestMapping("/api/files")
@CrossOrigin(origins = "*")
public class FileController {
    private final FileServiceStorage storage;

    public FileController(FileServiceStorage storage) {
        this.storage = storage;
    }

    private String authenticatedOwner() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equals(auth.getPrincipal())) {
            throw new org.springframework.security.access.AccessDeniedException("Authentication required");
        }
        return auth.getName();
    }

    @PostMapping("/upload")
    public ResponseEntity<?> uploadFile(
            @RequestParam("files") MultipartFile file,
            @RequestParam(value = "parentFolderId", required = false) Long parentFolderId) {
        try {
            String ownerId = authenticatedOwner();
            return ResponseEntity.ok(storage.saveFile(file, parentFolderId, ownerId));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "File upload failed"));
        }
    }

    @GetMapping("/download/{id}")
    public ResponseEntity<Resource> downloadFile(
            @PathVariable Long id) {
        try {
            String ownerId = authenticatedOwner();
            FileEntity file = storage.getFileById(id, ownerId);
            if (file.isDeleted()) return ResponseEntity.notFound().build();
            Resource resource = new UrlResource(Paths.get(file.getPath()).toUri());
            if (!resource.exists()) return ResponseEntity.notFound().build();

            return ResponseEntity.ok()
                    .contentType(resolveMediaType(file.getType()))
                    .header(HttpHeaders.CONTENT_DISPOSITION,
                            "inline; filename=\"" + file.getName().replace("\"", "") + "\"")
                    .body(resource);
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }

    @GetMapping
    public ResponseEntity<List<FileEntity>> listFiles(
            @RequestParam(value = "parentFolderId", required = false) Long parentFolderId,
            @RequestParam(value = "trash", defaultValue = "false") boolean trash,
            @RequestParam(value = "search", defaultValue = "") String search) {
        String ownerId = authenticatedOwner();
        return ResponseEntity.ok(storage.getFilesInFolder(parentFolderId, ownerId, trash, search));
    }

    @GetMapping("/storage")
    public ResponseEntity<Map<String, Long>> storage() {
        String ownerId = authenticatedOwner();
        long used = storage.getUsedStorage(ownerId);
        long limit = storage.getStorageLimit();
        return ResponseEntity.ok(Map.of("limit", limit, "used", used, "remaining", Math.max(0, limit - used)));
    }

    @PutMapping("/rename/{id}")
    public ResponseEntity<?> rename(
            @PathVariable Long id,
            @RequestBody Map<String, String> body) {
        try {
            storage.rename(id, body.get("name"), authenticatedOwner());
            return ResponseEntity.ok(Map.of("message", "Renamed successfully"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(404).body(Map.of("message", "File not found"));
        }
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> delete(@PathVariable Long id) {
        try {
            storage.moveToTrash(id, authenticatedOwner());
            return ResponseEntity.ok(Map.of("message", "Moved to trash"));
        } catch (Exception e) {
            return ResponseEntity.status(404).body(Map.of("message", "File not found"));
        }
    }

    @PutMapping("/restore/{id}")
    public ResponseEntity<?> restore(@PathVariable Long id) {
        try {
            storage.restore(id, authenticatedOwner());
            return ResponseEntity.ok(Map.of("message", "Restored"));
        } catch (Exception e) {
            return ResponseEntity.status(404).body(Map.of("message", "File not found"));
        }
    }

    @DeleteMapping("/permanent/{id}")
    public ResponseEntity<?> permanentDelete(@PathVariable Long id) {
        try {
            storage.permanentDelete(id, authenticatedOwner());
            return ResponseEntity.ok(Map.of("message", "Deleted permanently"));
        } catch (Exception e) {
            return ResponseEntity.status(404).body(Map.of("message", "File not found"));
        }
    }

    private MediaType resolveMediaType(String type) {
        try {
            return MediaType.parseMediaType(type);
        } catch (Exception ignored) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
    }

}
