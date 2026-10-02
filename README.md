# 🚀 Vault-Drive — Full-Stack Cloud Storage Application

Vault-Drive (DriftBox Drive) is an original enterprise-grade Cloud File Storage and Management Application built using **Spring Boot (Java 21)** for the backend RESTful web service and **Flutter (Dart)** with the **BLoC/Cubit state management pattern** for the cross-platform frontend interface.

> [!NOTE]
> **No Source Code Changes Made**: The application source code (`Drive-BE/src` and `Drive-FE/lib`) remains 100% intact and untouched. This document serves as a complete project specification, class-by-class technical breakdown, architectural map, and HR/Interview presentation guide.

---

## 📐 Architecture Overview

The system uses a **Decoupled Client-Server Architecture** communicating over HTTP/REST JSON endpoints and Multipart File Data transfers.

```
       +-----------------------------------------------------------+
       |                  FLUTTER FRONTEND (Drive-FE)             |
       |  - UI Layer: Material 3, Responsive Layouts, Drag & Drop   |
       |  - State Management: DriveCubit + DriveState (BLoC)      |
       |  - Network Layer: Dio HTTP Client + SharedPreferences     |
       +-----------------------------+-----------------------------+
                                     |  HTTP REST / JSON / Multipart
                                     v  (authenticated JWT user)
       +-----------------------------------------------------------+
       |                 SPRING BOOT BACKEND (Drive-BE)           |
       |  - Controller Layer: FileController (@RestController)     |
       |  - Service Layer: FileServiceStorage (@Service)          |
       |  - Data Access Layer: FileRepository (Spring Data JPA)   |
       +--------------+------------------------------+-------------+
                      |                              |
                      v                              v
        +---------------------------+  +---------------------------+
        |  MySQL Database           |  | Physical File System      |
        |  (Metadata, Trash, Size)  |  | (uploads/<uuid>_<name>)  |
        +---------------------------+  +---------------------------+
```

---

## 🛠 Tech Stack & Core Libraries

### Backend (`Drive-BE`)
- **Language**: Java 21
- **Framework**: Spring Boot 3.x (`spring-boot-starter-web`, `spring-boot-starter-data-jpa`)
- **Database**: MySQL (`drive_db` database, Hibernate ORM dialect)
- **File Storage**: Local Filesystem Storage under `uploads/` directory
- **Build Tool**: Maven

### Frontend (`Drive-FE`)
- **Framework**: Flutter 3.x (Dart)
- **State Management**: `flutter_bloc` (Cubit pattern for reactive UI updates)
- **HTTP Client**: `dio` (for asynchronous file uploads, progress tracking, REST calls)
- **Local Persistence**: `shared_preferences` (persists persistent client device `ownerId`)
- **File Picker & Utilities**: `file_picker` (multi-file select), `desktop_drop` (desktop drag-and-drop), `url_launcher` (external file opening), `intl` (date formatting)

---

## 🔍 Class-by-Class Technical Breakdown

### 🟢 BACKEND CLASSES (`Drive-BE`)

#### 1. `DriveBeApplication.java`
- **Location**: `com.Govind.Drive_BE.DriveBeApplication`
- **Role**: Application Bootstrapper
- **Logic**: Annotated with `@SpringBootApplication`. Contains the `main` method which invokes `SpringApplication.run()`, booting Tomcat server on port `8080` and scanning components across `com.Govind.Drive_BE`.

#### 2. `FileEntity.java`
- **Location**: `com.Govind.Drive_BE.entity.FileEntity`
- **Role**: JPA Data Model mapped to `files` database table.
- **Fields & Logic**:
  - `id` (`Long`, `@Id`, `@GeneratedValue(IDENTITY)`): Primary Key.
  - `name` (`String`): Original display name of the uploaded file.
  - `path` (`String`, 2048 chars): Disk path where the physical binary file is saved (`uploads/...`).
  - `size` (`Long`): Size of file in bytes.
  - `type` (`String`): MIME Content-Type (e.g. `application/pdf`, `image/png`, `video/mp4`).
  - `parentFolderId` (`Long`): Optional parent folder reference for hierarchical folder tree structure.
  - `createdAt` / `updatedAt` (`LocalDateTime`): Audit timestamps.
  - `deleted` (`boolean`, default `false`): Soft-delete flag for Trash functionality.
  - `ownerId` (`String`, default `'default'`): Client identifier header sent from frontend to isolate workspace files.

#### 3. `UserEntity.java`
- **Location**: `com.Govind.Drive_BE.entity.UserEntity`
- **Role**: JPA Data Model mapped to `users` database table.
- **Fields**: `id`, `name`, `Username`, `email`, `password`. Provides entity schema for user management features.

#### 4. `FileRepository.java`
- **Location**: `com.Govind.Drive_BE.repo.FileRepository`
- **Role**: Spring Data JPA Repository interface.
- **Key Methods & Logic**:
  - `findByOwnerIdAndParentFolderIdAndDeletedOrderByCreatedAtDesc`: Retrieves active/trashed files within a specific folder for an owner.
  - `findByOwnerIdAndDeletedOrderByCreatedAtDesc`: Retrieves all files for an owner filtered by `deleted` status, ordered latest first.
  - `findByOwnerIdAndDeletedFalseAndNameContainingIgnoreCaseOrderByCreatedAtDesc`: Case-insensitive title search among non-deleted files.
  - `@Query("select coalesce(sum(f.size), 0) from FileEntity f where f.ownerId = :ownerId and f.deleted = false")`: Custom JPQL aggregate query calculating total bytes consumed by an owner's active files.

#### 5. `FileServiceStorage.java`
- **Location**: `com.Govind.Drive_BE.services.FileServiceStorage`
- **Role**: Core Storage Business Logic Engine (`@Service`).
- **Logic & Rules**:
  - **Storage Limit**: Enforces a strict 1 GB hard limit (`1024 * 1024 * 1024` bytes) per `ownerId`.
  - `saveFile(...)`: Validates file size against total storage used. Sanitizes file names, generates unique stored names (`UUID + "_" + safeName`), writes the input stream to `uploadDir` (`uploads/`), and saves metadata entity into MySQL. Cleans up physical file on error.
  - `getFilesInFolder(...)`: Handles query filtering by search string, parent folder, or trash status.
  - `moveToTrash(...)`: Soft-deletes file (`deleted = true`).
  - `restore(...)`: Restores file from trash (`deleted = false`).
  - `permanentDelete(...)`: Hard-deletes file physically from disk storage (`Files.deleteIfExists`) and deletes record from MySQL database.
  - `rename(...)`: Modifies the display `name` metadata in MySQL without touching the physical disk filename to prevent broken file references.
  - `getUsedStorage(...)`: Computes total non-deleted file sizes.

#### 6. `FileController.java`
- **Location**: `com.Govind.Drive_BE.controller.FileController`
- **Role**: REST API Controller (`@RestController`, `@RequestMapping("/api/files")`, `@CrossOrigin("*")`).
- **Endpoints**:
  - `POST /upload`: Uploads single/multiple files (`MultipartFile`), returns status message.
  - `GET /download/{id}`: Streams binary content via `UrlResource` with `Content-Disposition: inline` for in-app preview or download.
  - `GET`: Returns list of files (supports `parentFolderId`, `trash`, `search` query params, and authenticated JWT identity).
  - `GET /storage`: Returns storage metrics `{limit, used, remaining}`.
  - `PUT /rename/{id}`: Renames file metadata.
  - `DELETE /delete/{id}`: Soft-deletes file to trash.
  - `PUT /restore/{id}`: Restores file from trash.
  - `DELETE /permanent/{id}`: Permanently deletes file.

---

### 🔵 FRONTEND CLASSES (`Drive-FE`)

#### 1. `main.dart`
- **Role**: Application Root Entry point.
- **Logic**: Configures `RepositoryProvider` (injecting `DriveRepository`) and `BlocProvider` (instantiating `DriveCubit` and auto-triggering initial `load()`). Applies custom Light and Dark Material 3 theme schemes based on `AppColors`.

#### 2. `core/theme/app_colors.dart` & `core/constants/app_sizes.dart`
- **Role**: Centralized Design System Design System Tokens.
- **Tokens**: `accent` (Indigo `#6366F1`), `accentSoft`, `ink`, `cloud`, `paper`, `darkCard`, `danger`. Spacing: `pagePadding` (20.0), `cardRadius` (18.0), `headerHeight` (64.0).

#### 3. `core/utils/file_utils.dart`
- **Role**: Utility helper functions.
- **Functions**:
  - `formatBytes(int bytes)`: Converts raw byte count to readable string (`KB`, `MB`, `GB`).
  - `fileIcon(String name)`: Maps extensions (`.pdf`, `.txt`, `.png`, `.mp4`, etc.) to corresponding Material icons.

#### 4. `data/models/drive_file.dart`
- **Role**: Data Model representing a file object received from REST backend.
- **Fields**: `id`, `name`, `path`, `size`, `type`, `createdAt`, `updatedAt`, `deleted`. Contains `DriveFile.fromJson` parser with null-safety defaults.

#### 5. `data/repositories/drive_repository.dart`
- **Role**: Service Repository handling HTTP communication with backend API using `Dio`.
- **Logic**:
  - **Dynamic Host Resolution**: Detects environment (`http://10.0.2.2:8080/api` for Android Emulator, `http://localhost:8080/api` for Web/Desktop).
  - **Owner Isolation**: Uses `SharedPreferences` to manage a persistent unique device/workspace key (`drive_owner_id`), attaching authenticated JWT identity to every request.
  - **Upload Progress Callback**: Streams file data (`FormData`) with real-time percentage progress callback.

#### 6. `features/drive/bloc/drive_bloc.dart`
- **Role**: State Management using BLoC/Cubit (`DriveCubit` and `DriveState`).
- **State Properties**: `files` list, `storage` info, `view` (`DriveView.files` or `DriveView.trash`), `search` term, `loading` flag, `uploading` flag, `uploadProgress` double, `error` string, `message` string.
- **Cubit Actions**:
  - `load()`: Re-fetches files and storage quota concurrently.
  - `uploadFiles()`: Batch processes files sequentially while updating granular progress.
  - `rename()`, `moveToTrash()`, `restore()`, `permanentDelete()`: Performs actions and refreshes state with feedback messages.

#### 7. `features/user/screen/login_screen.dart`
- **Role**: Authentication Gateway Screen.
- **UI Elements**: Custom Vault-Drive branding, Username/Email & Password input fields, Remember Me checkbox, Google Sign-In mockup button, and link to Account Creation.

#### 8. `features/user/screen/create_account_screen.dart`
- **Role**: User Onboarding & Profile Setup Screen.
- **UI Elements**: Animated curved gradient header, animated avatar (`TweenAnimationBuilder`), inputs for Username, First/Last Name, Phone, Email, and Save & Continue action.

#### 9. `features/drive/screens/profile.dart`
- **Role**: User Profile Dashboard.
- **UI Elements**: User details display card (Full Name, Username, Email, Phone), and "Delete Account" button with confirmation alert dialog.

#### 10. `features/drive/screens/drive_screen.dart`
- **Role**: Main Storage Dashboard Interface.
- **UI & Interaction Logic**:
  - **AppBar**: Branding title, Profile page navigation button, and manual Refresh action button.
  - **Search Bar**: Input field with **350ms Debounce Timer** to avoid spamming the backend search API on every keypress.
  - **Segmented View Toggle**: Seamlessly switches UI between active `Files` and `Trash`.
  - **Drag-and-Drop (`DropTarget`)**: Allows desktop/web users to drag files from OS directly into the browser/window.
  - **File Picker (`_pickFiles`)**: System file picker supporting documents, images, and videos.
  - **File Viewer (`_openFile`)**: Displays images in-app inside interactive modal (`InteractiveViewer`) and opens external documents/videos via `url_launcher`.
  - **Progress Bar**: Displays upload progress bar while files are uploading.

#### 11. `features/drive/widgets/storage_card.dart`
- **Role**: Storage Quota Indicator Widget.
- **UI Elements**: Shows `LinearProgressIndicator` filled based on `used / limit`, text displaying used space vs 1 GB limit, and remaining available space.

#### 12. `features/drive/widgets/file_tile.dart`
- **Role**: Individual File Item List Tile.
- **UI Elements**: File type icon, file title, formatted size, formatted date, and dynamic context menu (`PopupMenuButton`) rendering actions based on tab (`Open`, `Rename`, `Move to Trash` for active files; `Restore`, `Delete Permanently` for trash view).

---

## 🗣 HR / Technical Interview Presentation Guide (Step-by-Step)

When presenting this project to an HR interviewer or Technical Panel, follow this structured storyline:

### 1. High-Level Pitch (The "Elevator Pitch")
> "Vault-Drive is a full-stack, enterprise-style cloud storage application built with a Java 21 Spring Boot backend and a cross-platform Flutter frontend using the BLoC pattern. It provides cloud file management features including multi-file drag-and-drop uploads, storage quota tracking (1 GB limit), file search with debouncing, soft deletion (Trash & Restore), image previews, and isolated workspace storage."

### 2. Architecture & Design Decisions
> "I chose a decoupled architecture to ensure separation of concerns:
> - **Backend**: Spring Boot provides strong data validation, file stream processing, and REST API controllers backed by MySQL and Hibernate ORM.
> - **Frontend**: Flutter gives a single codebase for Web, Android, iOS, and Desktop. I implemented the **BLoC/Cubit pattern** to ensure reactive state updates, clean separation of UI from business logic, and predictable state flows."

### 3. Data Flow & Execution Sequence
> "When a user uploads a file:
> 1. The user picks or drags a file into `DriveScreen`.
> 2. `DriveCubit` triggers `uploadFiles()`, updating state to show progress.
> 3. `DriveRepository` sends a Multipart POST request using `Dio` with a unique persistent authenticated JWT identity.
> 4. `FileController` in Spring Boot receives the file and passes it to `FileServiceStorage`.
> 5. The service calculates if `used + new_file_size <= 1 GB`. If valid, it writes the file to disk with a UUID prefix (`uploads/<uuid>_<safename>`) and saves file metadata in MySQL via `FileRepository`.
> 6. On response, `DriveCubit` refreshes file list and storage quota, instantly updating the UI."

### 4. Key Engineering Highlights to Mention
- **1 GB Storage Quota Logic**: Real-time aggregation of active file sizes in SQL (`COALESCE(SUM(size), 0)`). Soft-deleted files are excluded from quota, enabling users to free up space when moving files to trash.
- **File Name Sanitization & Physical Safety**: Disk filenames use UUID prefixes and sanitized paths to prevent path traversal attacks or duplicate filename overwrites, while DB metadata preserves original display names.
- **Debounced Search**: 350ms debounce timer on input prevents unnecessary network requests while typing.
- **Responsive & Accessible UI**: Supports dark/light mode, custom design tokens, drag-and-drop target overlays, and progress monitoring.

### 5. Potential HR / Technical Questions & Answers

| Question | Answer |
| :--- | :--- |
| **Why did you choose Spring Boot for Backend?** | Spring Boot offers production-grade features out of the box: dependency injection, Spring Data JPA for easy query abstraction, robust HTTP stream handling for large files, and clean layered architecture (Controller-Service-Repository). |
| **Why did you use Flutter BLoC instead of setState?** | `setState` makes code unmaintainable in large apps. BLoC/Cubit decouples UI components from business logic, making the code testable, reusable, and predictable. UI simply re-renders based on emitted state. |
| **How do you handle file security and isolation?** | Each authenticated user is isolated by their server-validated username from the JWT. Each user has an independent 1 GB quota and a separate physical upload directory. Files are stored on disk with UUID filenames to prevent direct exposure or overwrite conflicts. |
| **How does soft deletion (Trash) work?** | Setting `deleted = true` in MySQL hides files from the main view and excludes their size from quota calculations. Users can either restore the file or permanently delete both the database record and physical disk file. |

---

## ⚡ How to Run the Project

### 1. Prerequisites
- **Java 21 JDK** & **Maven**
- **MySQL Server** (running locally on port `3306`)
- **Flutter SDK 3.x**

### 2. Backend Setup (`Drive-BE`)
1. Create MySQL Database:
   ```sql
   CREATE DATABASE drive_db;
   ```
2. Verify credentials in `Drive-BE/src/main/resources/application.properties` (default: `username=root`, `password=mysql12`).
3. Run Spring Boot application:
   ```bash
   cd Drive-BE
   mvnw.cmd spring-boot:run
   ```
   Backend starts on `http://localhost:8080/api`.

### 3. Frontend Setup (`Drive-FE`)
1. Navigate to Flutter project:
   ```bash
   cd Drive-FE
   flutter pub get
   flutter run
   ```
   *(Note: Android Emulator automatically routes to `http://10.0.2.2:8080/api`, Web/Desktop routes to `http://localhost:8080/api`)*
