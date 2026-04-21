// UserDetailsServiceImpl.java - this file is part of skills-testing-system
// Copyright (C) 2026  Kirill Rudkovskii
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
