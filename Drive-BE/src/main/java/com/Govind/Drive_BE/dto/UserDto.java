package com.Govind.Drive_BE.dto;

public class UserDto {
    private Long id;
    private String name;
    private String username;
    private String email;
    private boolean verified;

    public UserDto() {}

    public UserDto(Long id, String name, String username, String email, boolean verified) {
        this.id = id;
        this.name = name;
        this.username = username;
        this.email = email;
        this.verified = verified;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public boolean isVerified() { return verified; }
    public void setVerified(boolean verified) { this.verified = verified; }
}
