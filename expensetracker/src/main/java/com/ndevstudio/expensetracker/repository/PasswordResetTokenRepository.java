package com.ndevstudio.expensetracker.repository;

import com.ndevstudio.expensetracker.entity.PasswordResetToken;
import com.ndevstudio.expensetracker.entity.User;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT t FROM PasswordResetToken t WHERE t.tokenHash = :tokenHash")
    Optional<PasswordResetToken> findByTokenHashForUpdate(@Param("tokenHash") String tokenHash);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE PasswordResetToken t SET t.usedAt = :usedAt WHERE t.user = :user AND t.usedAt IS NULL")
    int invalidateAllUnusedForUser(@Param("user") User user, @Param("usedAt") Instant usedAt);

    List<PasswordResetToken> findByUser(User user);
}
