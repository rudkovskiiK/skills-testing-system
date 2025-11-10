package org.air_river.skills_testing_system.models;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

@Entity
@Table(
    name = "results",
    uniqueConstraints = {
        @UniqueConstraint(
            columnNames = {"student_id", "task_id"}
        )
    }
)
@JsonIgnoreProperties(ignoreUnknown = true)
public class Result {
    private Integer id;
    private Student student;
    private Task task;
    private String code;
    private Boolean status;

    public Result() {}

    public Result(Student student, Task task) {
        this.id = null;
        this.student = student;
        this.task = task;
        this.code = "";
        this.status = false;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Integer getId() {
        return id;
    }
    public void setId(Integer id) {
        this.id = id;
    }

    @ManyToOne
    @JoinColumn(name = "student_id")
    public Student getStudent() {
        return student;
    }
    public void setStudent(Student student) {
        this.student = student;
    }

    @ManyToOne
    @JoinColumn(name = "task_id")
    public Task getTask() {
        return task;
    }
    public void setTask(Task task) {
        this.task = task;
    }

    @Column(name = "code", nullable = false)
    public String getCode() {
        return code;
    }
    public void setCode(String code) {
        this.code = code;
    }

    @Column(name = "status", nullable = false)
    public Boolean getStatus() {
        return status;
    }
    public void setStatus(Boolean status) {
        this.status = status;
    }

    @Override
    public boolean equals(Object obj) {
        if(this == obj) return true;
        if(obj == null || getClass() != obj.getClass()) return false;
        Result r = (Result)obj;
        if(!(id == null ? r.id == null : id.equals(r.id))) return false;
        if(!(student == null ? r.student == null : student.equals(r.student))) return false;
        if(!(task == null ? r.task == null : task.equals(r.task))) return false;
        if(!(code == null ? r.code == null : code.equals(r.code))) return false;
        if(!(status == null ? r.status == null : status.equals(r.status))) return false;
        return true;
    }

    @Override
    public int hashCode() {
        int hash = id == null ? 0 : id.hashCode();
        hash += student == null ? 0 : student.hashCode();
        hash += task == null ? 0 : task.hashCode();
        hash += code == null ? 0 : code.hashCode();
        hash += status == null ? 0 : status.hashCode();
        return hash;
    }
}
