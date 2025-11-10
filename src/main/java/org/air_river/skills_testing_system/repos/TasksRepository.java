package org.air_river.skills_testing_system.repos;
import org.springframework.data.repository.CrudRepository;
import org.air_river.skills_testing_system.models.Task;

public interface TasksRepository extends CrudRepository<Task, Long> {}
