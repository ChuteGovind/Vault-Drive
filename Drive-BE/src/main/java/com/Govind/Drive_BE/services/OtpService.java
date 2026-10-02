package com.Govind.Drive_BE.services;

import com.Govind.Drive_BE.dto.RegisterRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class OtpService {

    private static final Logger logger = LoggerFactory.getLogger(OtpService.class);
    private static final int OTP_VALIDITY_MINUTES = 10;

    @Autowired(required = false)
    private JavaMailSender mailSender;

    public static class PendingRegistration {
        private final RegisterRequest registerRequest;
        private final String otp;
        private final LocalDateTime expiresAt;

        public PendingRegistration(RegisterRequest registerRequest, String otp, LocalDateTime expiresAt) {
            this.registerRequest = registerRequest;
            this.otp = otp;
            this.expiresAt = expiresAt;
        }

        public RegisterRequest getRegisterRequest() { return registerRequest; }
        public String getOtp() { return otp; }
        public LocalDateTime getExpiresAt() { return expiresAt; }
    }

    private final Map<String, PendingRegistration> pendingRegistrations = new ConcurrentHashMap<>();
    private final SecureRandom random = new SecureRandom();

    public String generateAndSaveOtp(RegisterRequest request) {
        // Generate 4-digit OTP between 1000 and 9999
        int code = 1000 + random.nextInt(9000);
        String otp = String.valueOf(code);

        String email = request.getEmail().toLowerCase().trim();
        LocalDateTime expiresAt = LocalDateTime.now().plusMinutes(OTP_VALIDITY_MINUTES);

        PendingRegistration pending = new PendingRegistration(request, otp, expiresAt);
        pendingRegistrations.put(email, pending);

        // Attempt to send email
        sendEmailOtp(email, otp);

        return otp;
    }

    private void sendEmailOtp(String email, String otp) {
        String messageBody = "Your verification code for Vault Drive is: " + otp + "\nThis code will expire in 10 minutes.";
        
        logger.info("=================================================");
        logger.info("SECURITY OTP GENERATED FOR [{}]: [{}]", email, otp);
        logger.info("=================================================");

        if (mailSender != null) {
            try {
                SimpleMailMessage message = new SimpleMailMessage();
                message.setTo(email);
                message.setSubject("Vault Drive - Email Verification Code");
                message.setText(messageBody);
                mailSender.send(message);
                logger.info("Successfully sent OTP email to {}", email);
            } catch (Exception e) {
                logger.warn("Failed to send email via JavaMailSender: {}. OTP is printed in logs above.", e.getMessage());
            }
        } else {
            logger.info("JavaMailSender is not configured; logged OTP to console for local testing.");
        }
    }

    public PendingRegistration getPendingRegistration(String email) {
        if (email == null) return null;
        return pendingRegistrations.get(email.toLowerCase().trim());
    }

    public boolean verifyOtp(String email, String inputOtp) {
        if (email == null || inputOtp == null) return false;

        String key = email.toLowerCase().trim();
        PendingRegistration pending = pendingRegistrations.get(key);

        if (pending == null) {
            return false;
        }

        if (LocalDateTime.now().isAfter(pending.getExpiresAt())) {
            pendingRegistrations.remove(key);
            return false;
        }

        boolean isValid = pending.getOtp().equals(inputOtp.trim());
        if (isValid) {
            // Remove after single successful verification
            pendingRegistrations.remove(key);
        }
        return isValid;
    }
}
