package org.air_river.skills_testing_system.services;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.air_river.skills_testing_system.models.Student;

@Service
public class UserDetailsServiceImpl implements UserDetailsService {
    @Autowired
    private StudentsTestService studentsTestService;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        Student student = studentsTestService.getStudentsWithLoginPermission()
            .stream()
            .filter(s -> username.equals(s.getId().toString()))
            .findAny()
            .orElseThrow(() -> new UsernameNotFoundException("There is no student with login '" + username + "'!"));
        return User.builder().username(username).password(student.getPassword()).build();
    }
}
