package org.air_river.skills_testing_system.models;
import java.util.ArrayList;
import java.util.List;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;

@Entity
@Table(name = "students")
@JsonIgnoreProperties(ignoreUnknown = true)
public class Student {
    private Integer id;
    private String fullName;
    private Boolean loginPermission;
    private Integer nextTaskClickCount;
    private Group group;
    @JsonIgnore
    private String password;
    private List<Task> tasks = new ArrayList<Task>();
    private List<Result> results = new ArrayList<Result>();

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Integer getId() {
        return id;
    }
    public void setId(final Integer id) {
        this.id = id;
    }

    @Column(name = "full_name", length = 150, nullable = false)
    public String getFullName() {
        return fullName;
    }
    public void setFullName(final String fullName) {
        this.fullName = fullName;
    }

    @Column(name = "login_permission", nullable = false)
    public Boolean getLoginPermission() {
        return loginPermission;
    }
    public void setLoginPermission(Boolean loginPermission) {
        this.loginPermission = loginPermission;
    }

    @Column(name = "next_task_click_count", nullable = false)
    public Integer getNextTaskClickCount() {
        return nextTaskClickCount;
    }
    public void setNextTaskClickCount(Integer nextTaskClickCount) {
        this.nextTaskClickCount = nextTaskClickCount;
    }

    @ManyToOne
    @JoinColumn(name = "group_id")
    public Group getGroup() {
        return group;
    }
    public void setGroup(final Group group) {
        this.group = group;
    }

    @Column(name = "password", length = 60, nullable = false)
    public String getPassword() {
        return password;
    }
    public void setPassword(String password) {
        this.password = password;
    }

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
        name = "students_tasks",
        joinColumns = @JoinColumn(
            name = "student_id",
            referencedColumnName = "id"
        ),
        inverseJoinColumns = @JoinColumn(
            name = "task_id",
            referencedColumnName = "id"
        )
    )
    @OrderBy("id")
    public List<Task> getTasks() {
        return tasks;
    }
    public void setTasks(List<Task> tasks) {
        this.tasks = tasks;
    }

    @OneToMany(mappedBy = "student", fetch = FetchType.EAGER)
    @OrderBy("task_id")
    public List<Result> getResults() {
        return results;
    }
    public void setResults(List<Result> results) {
        this.results = results;
    }

    @Override
    public boolean equals(Object obj) {
        if(this == obj) return true;
        if(obj == null || getClass() != obj.getClass()) return false;
        Student st = (Student)obj;
        if(!(id == null ? st.id == null : id.equals(st.id))) return false;
        if(!(fullName == null ? st.fullName == null : fullName.equals(st.fullName))) return false;
        if(!(loginPermission == null ? st.loginPermission == null : loginPermission.equals(st.loginPermission))) return false;
        if(!(nextTaskClickCount == null ? st.nextTaskClickCount == null : nextTaskClickCount.equals(st.nextTaskClickCount))) return false;
        if(!(group == null ? st.group == null : group.equals(st.group))) return false;
        if(!(password == null ? st.password == null : password.equals(st.password))) return false;
        return true;
    }

    @Override
    public int hashCode() {
        int hash = id == null ? 0 : id.hashCode();
        hash += fullName == null ? 0 : fullName.hashCode();
        hash += loginPermission == null ? 0 : loginPermission.hashCode();
        hash += nextTaskClickCount == null ? 0 : nextTaskClickCount.hashCode();
        hash += group == null ? 0 : group.hashCode();
        hash += password == null ? 0 : password.hashCode();
        return hash;
    }
}
