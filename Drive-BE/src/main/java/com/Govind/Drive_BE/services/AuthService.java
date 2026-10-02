package com.Govind.Drive_BE.services;

import com.Govind.Drive_BE.dto.*;
import com.Govind.Drive_BE.entity.UserEntity;
import com.Govind.Drive_BE.repo.UserRepository;
import com.Govind.Drive_BE.security.JwtUtils;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final OtpService otpService;
    private final JwtUtils jwtUtils;
    private final FileServiceStorage fileStorage;

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       OtpService otpService,
                       JwtUtils jwtUtils,
                       FileServiceStorage fileStorage) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.otpService = otpService;
        this.jwtUtils = jwtUtils;
        this.fileStorage = fileStorage;
    }

    public String requestRegisterOtp(RegisterRequest request) {
        if (request.getUsername() == null || request.getUsername().isBlank()) {
            throw new IllegalArgumentException("Username is required");
        }
        if (request.getEmail() == null || request.getEmail().isBlank()) {
            throw new IllegalArgumentException("Email is required");
        }
        if (request.getPassword() == null || request.getPassword().isBlank()) {
            throw new IllegalArgumentException("Password is required");
        }

        String username = request.getUsername().trim();
        String email = request.getEmail().trim().toLowerCase();

        if (userRepository.existsByUsername(username)) {
            throw new IllegalArgumentException("Username '" + username + "' is already taken");
        }
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email '" + email + "' is already registered");
        }

        return otpService.generateAndSaveOtp(request);
    }

    @Transactional
    public AuthResponse verifyOtpAndRegister(VerifyOtpRequest request) {
        String email = request.getEmail() != null ? request.getEmail().trim().toLowerCase() : "";
        String otp = request.getOtp() != null ? request.getOtp().trim() : "";

        if (email.isBlank() || otp.isBlank()) {
            throw new IllegalArgumentException("Email and OTP are required");
        }

        OtpService.PendingRegistration pending = otpService.getPendingRegistration(email);
        if (pending == null) {
            throw new IllegalArgumentException("No pending registration found for email: " + email + ". Please request a new OTP.");
        }

        boolean verified = otpService.verifyOtp(email, otp);
        if (!verified) {
            throw new IllegalArgumentException("Invalid or expired 4-digit OTP code");
        }

        RegisterRequest regDetails = pending.getRegisterRequest();
        
        // Double check username/email availability
        if (userRepository.existsByUsername(regDetails.getUsername().trim())) {
            throw new IllegalArgumentException("Username is already in use");
        }
        if (userRepository.existsByEmail(regDetails.getEmail().trim().toLowerCase())) {
            throw new IllegalArgumentException("Email is already in use");
        }

        UserEntity user = new UserEntity();
        user.setName(regDetails.getName() != null ? regDetails.getName().trim() : regDetails.getUsername().trim());
        user.setUsername(regDetails.getUsername().trim());
        user.setEmail(regDetails.getEmail().trim().toLowerCase());
        user.setPassword(passwordEncoder.encode(regDetails.getPassword()));
        user.setVerified(true);

        UserEntity savedUser = userRepository.save(user);

        String token = jwtUtils.generateToken(savedUser.getUsername());
        UserDto userDto = new UserDto(savedUser.getId(), savedUser.getName(), savedUser.getUsername(), savedUser.getEmail(), savedUser.isVerified());

        return new AuthResponse(token, userDto, "Account successfully registered and verified!");
    }

    public AuthResponse login(LoginRequest request) {
        String input = request.getEmailOrUsername() != null ? request.getEmailOrUsername().trim() : "";
        String rawPassword = request.getPassword() != null ? request.getPassword() : "";

        if (input.isBlank() || rawPassword.isBlank()) {
            throw new IllegalArgumentException("Email/Username and password are required");
        }

        UserEntity user = userRepository.findByUsernameOrEmail(input, input.toLowerCase())
                .orElseThrow(() -> new IllegalArgumentException("Invalid email/username or password"));

        if (!passwordEncoder.matches(rawPassword, user.getPassword())) {
            throw new IllegalArgumentException("Invalid email/username or password");
        }

        String token = jwtUtils.generateToken(user.getUsername());
        UserDto userDto = new UserDto(user.getId(), user.getName(), user.getUsername(), user.getEmail(), user.isVerified());

        return new AuthResponse(token, userDto, "Login successful");
    }

    @Transactional
    public void deleteAccount(String username) {
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        fileStorage.deleteAllFilesForOwner(user.getUsername());
        userRepository.delete(user);
    }

    public UserDto getUserByUsername(String username) {
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + username));
        return new UserDto(user.getId(), user.getName(), user.getUsername(), user.getEmail(), user.isVerified());
    }
}
