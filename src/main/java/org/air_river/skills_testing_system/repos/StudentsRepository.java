package org.air_river.skills_testing_system.repos;
import org.springframework.data.repository.CrudRepository;
import org.air_river.skills_testing_system.models.Student;

public interface StudentsRepository extends CrudRepository<Student, Long> {
    //public Iterable<Student> findAllByOrderById();
    public Iterable<Student> findByLoginPermissionTrueOrderById();
}
