package com.ndevstudio.expensetracker.service;

import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.UserRepository;
import lombok.Data;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.Optional;

@Service
public class UserService {
    private UserRepository userRepository;

    @Autowired
    UserService(UserRepository userRepository){
        this.userRepository = userRepository;
    }

    Optional<User> findUserByMail(String email){
        return userRepository.findByEmail(email);
    }

    User createUser(User user){
        if(userRepository.existsByEmail(user))
            return userRepository.save(user);
        return null;
    }
}
