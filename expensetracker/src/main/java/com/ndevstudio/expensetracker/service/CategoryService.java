package com.ndevstudio.expensetracker.service;

import com.ndevstudio.expensetracker.entity.Category;
import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.CategoryRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CategoryService {
    private CategoryRepository categoryRepository;
    private UserRepository userRepository;

    @Autowired
    CategoryService(CategoryRepository categoryRepository, UserRepository userRepository) {
        this.categoryRepository = categoryRepository;
        this.userRepository = userRepository;
    }

    //Read
    public ResponseEntity<List<Category>> readAllCategory(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        List<Category> categories = categoryRepository.findByUserId(user.getId());
        return new ResponseEntity<>(categories, HttpStatus.OK);
    }

    //Create
    public ResponseEntity<Category> createCategory(Category newCategory, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        newCategory.setUser(user);
        Category c = categoryRepository.save(newCategory);
        return new ResponseEntity<>(c, HttpStatus.CREATED);
    }

    public ResponseEntity<List<Category>> readCategoryByUser(Long userId) {
        List<Category> categories = categoryRepository.findByUserId(userId);
        return new ResponseEntity<>(categories, HttpStatus.OK);
    }

    //Update
    public ResponseEntity<Category> updateCategory(Category newCategory, long id, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        Category oldCategory = categoryRepository.findById(id).orElse(null);
        if (oldCategory == null) {
            return new ResponseEntity<>(null, HttpStatus.NOT_FOUND);
        }
        if (oldCategory.getUser().getId() != user.getId()) {
            return new ResponseEntity<>(null, HttpStatus.UNAUTHORIZED);
        }
        oldCategory.setName(newCategory.getName());
        oldCategory.setIcon(newCategory.getIcon());
        oldCategory.setColor(newCategory.getColor());
        categoryRepository.save(oldCategory);
        return new ResponseEntity<>(oldCategory, HttpStatus.OK);
    }

    //Delete
    public ResponseEntity<String> deleteCategory(long id, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        Category category = categoryRepository.findById(id).orElse(null);
        if (category == null) {
            return new ResponseEntity<>("Category not found", HttpStatus.NOT_FOUND);
        }
        if (category.getUser().getId() != user.getId()) {
            return new ResponseEntity<>("Unauthorized", HttpStatus.UNAUTHORIZED);
        }
        categoryRepository.delete(category);
        return new ResponseEntity<>("Category deleted", HttpStatus.OK);
    }
}