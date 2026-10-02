package com.Govind.Drive_BE.controller;

import com.Govind.Drive_BE.dto.*;
import com.Govind.Drive_BE.services.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
@Tag(name = "Authentication", description = "Endpoints for Registration with 4-Digit Email OTP, Login, and User Profile")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register-otp")
    @Operation(summary = "Send 4-Digit OTP to Email for Registration", description = "Validates user details and sends a 4-digit OTP to the user's email address.")
    public ResponseEntity<?> requestRegisterOtp(@RequestBody RegisterRequest request) {
        try {
            String otp = authService.requestRegisterOtp(request);
            return ResponseEntity.ok(Map.of(
                    "message", "4-digit OTP sent to " + request.getEmail() + ". Please verify to complete account registration.",
                    "email", request.getEmail()
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Failed to process OTP request: " + e.getMessage()));
        }
    }

    @PostMapping("/verify-otp")
    @Operation(summary = "Verify 4-Digit OTP & Complete Registration", description = "Verifies the 4-digit OTP and creates the verified user account.")
    public ResponseEntity<?> verifyOtpAndRegister(@RequestBody VerifyOtpRequest request) {
        try {
            AuthResponse response = authService.verifyOtpAndRegister(request);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Failed to verify OTP: " + e.getMessage()));
        }
    }

    @PostMapping("/login")
    @Operation(summary = "User Login via Email/Username and Password", description = "Authenticates user using email or username along with password, returning JWT Bearer token.")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        try {
            AuthResponse response = authService.login(request);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Login error: " + e.getMessage()));
        }
    }

    @DeleteMapping("/me")
    @Operation(summary = "Delete Current User Account", description = "Deletes the authenticated user and all of their stored files.")
    public ResponseEntity<?> deleteCurrentUser(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("message", "Not authenticated"));
        }
        try {
            authService.deleteAccount(authentication.getName());
            return ResponseEntity.ok(Map.of("message", "Account deleted successfully"));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/me")
    @Operation(summary = "Get Current User Profile", description = "Returns profile details of the currently authenticated user.")
    public ResponseEntity<?> getCurrentUser(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("message", "Not authenticated"));
        }
        try {
            UserDto user = authService.getUserByUsername(authentication.getName());
            return ResponseEntity.ok(user);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("message", e.getMessage()));
        }
    }
}
