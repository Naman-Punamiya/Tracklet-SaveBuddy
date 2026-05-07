package com.ndevstudio.expensetracker.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name="Investments")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Investment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private long id;
}
