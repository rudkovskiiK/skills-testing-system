package org.air_river.skills_testing_system.models;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "tasks")
@JsonIgnoreProperties(ignoreUnknown = true)
public class Task {
    private Integer id;
    private String description;
    private String answer;
    private Integer difficultyLevel;
    private String language;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Integer getId() {
        return id;
    }
    public void setId(Integer id) {
        this.id = id;
    }

    @Column(name = "description", nullable = false, unique = true)
    public String getDescription() {
        return description;
    }
    public void setDescription(String description) {
        this.description = description;
    }

    @Column(name = "answer", nullable = false)
    public String getAnswer() {
        return answer;
    }
    public void setAnswer(String answer) {
        this.answer = answer;
    }

    @Column(name = "difficulty_level", nullable = false)
    public Integer getDifficultyLevel() {
        return difficultyLevel;
    }
    public void setDifficultyLevel(Integer difficultyLevel) {
        this.difficultyLevel = difficultyLevel;
    }

    @Column(name = "language", nullable = false)
    public String getLanguage() {
        return language;
    }
    public void setLanguage(String language) {
        this.language = language;
    }

    @Override
    public boolean equals(Object obj) {
        if(this == obj) return true;
        if(obj == null || getClass() != obj.getClass()) return false;
        Task t = (Task)obj;
        if(!(id == null ? t.id == null : id.equals(t.id))) return false;
        if(!(description == null ? t.description == null : description.equals(t.description))) return false;
        if(!(answer == null ? t.answer == null : answer.equals(t.answer))) return false;
        if(!(difficultyLevel == null ? t.difficultyLevel == null : difficultyLevel.equals(t.difficultyLevel))) return false;
        if(!(language == null ? t.language == null : language.equals(t.language))) return false;
        return true;
    }

    @Override
    public int hashCode() {
        int hash = id == null ? 0 : id.hashCode();
        hash += description == null ? 0 : description.hashCode();
        hash += answer == null ? 0 : answer.hashCode();
        hash += difficultyLevel == null ? 0 : difficultyLevel.hashCode();
        hash += language == null ? 0 : language.hashCode();
        return hash;
    }
}
