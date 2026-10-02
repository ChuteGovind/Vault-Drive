package com.Govind.Drive_BE.repo;

import com.Govind.Drive_BE.entity.FileEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface FileRepository extends JpaRepository<FileEntity, Long> {
    List<FileEntity> findByOwnerIdAndParentFolderIdAndDeletedOrderByCreatedAtDesc(
            String ownerId, Long parentFolderId, boolean deleted);

    List<FileEntity> findByOwnerIdAndDeletedOrderByCreatedAtDesc(
            String ownerId, boolean deleted);

    List<FileEntity> findByOwnerIdAndDeletedFalseAndNameContainingIgnoreCaseOrderByCreatedAtDesc(
            String ownerId, String name);

    @Query("select coalesce(sum(f.size), 0) from FileEntity f where f.ownerId = :ownerId and f.deleted = false")
    Long sumSizeByOwnerIdAndDeletedFalse(@Param("ownerId") String ownerId);

    List<FileEntity> findByOwnerId(String ownerId);
}
