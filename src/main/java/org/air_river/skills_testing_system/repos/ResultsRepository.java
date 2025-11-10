package org.air_river.skills_testing_system.repos;
import org.springframework.data.repository.CrudRepository;
import org.air_river.skills_testing_system.models.Result;

public interface ResultsRepository extends CrudRepository<Result, Long> {
    //List<Result> findByStudentIdAndTaskId(Long studentId, Long taskId);
}
