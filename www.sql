--  ***** BEGIN LICENSE BLOCK *****
--  
--  This file is part of the fork of the vanilla Zotero Data Server.
--  
--  Copyright © 2014 Patrick Höhn
--  
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU Affero General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--  
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU Affero General Public License for more details.
--  
--  You should have received a copy of the GNU Affero General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--  
--  ***** END LICENSE BLOCK *****

CREATE TABLE `sessions` (
`userID` mediumint unsigned NOT NULL,
`id` int(10) unsigned NOT NULL,
`modified` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
`lifetime` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00', 
    PRIMARY KEY (`userID`, `id`),
  FOREIGN KEY (`userID`) REFERENCES `users` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `users_email` (
`userID` mediumint unsigned NOT NULL,
`email` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  PRIMARY KEY (`userID`),
  UNIQUE KEY (`email`), 
  FOREIGN KEY (`userID`) REFERENCES `users` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `storage_institutions` (
`storageQuota` mediumintt(8) unsigned NOT NULL,
`domain` varchar(255) NOT NULL,
`institutionID` int(10) unsigned NOT NULL,
PRIMARY KEY (`institutionID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `storage_institution_email` (
`email` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
`institutionID` int(10) unsigned NOT NULL,
  PRIMARY KEY (`institutionID`),
  FOREIGN KEY (`institutionID`) REFERENCES `storage_institutions` (`institutionID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `users` (
`userID` mediumint unsigned auto_increment NULL,
`username` varchar(40) NOT NULL,
`password` char(61) NOT NULL,
PRIMARY KEY (`username`, `userID`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `userID` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `users_meta` (
`userID` mediumint unsigned NOT NULL,
`metaKey` enum('profile_realname', 'publishLibrary', 'publishNotes') NOT NULL,
`metaValue` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci  NOT NULL,
FOREIGN KEY (`userID`) REFERENCES `users` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8  COLLATE=utf8_general_ci;

CREATE TABLE `LUM_User` (
`UserID` int(10) unsigned NOT NULL,
`RoleID` int(10) unsigned NOT NULL,
  PRIMARY KEY (`UserID`, `RoleID`),
  FOREIGN KEY (`RoleID`) REFERENCES `LUM_Role` (`RoleID`),
  FOREIGN KEY (`UserID`) REFERENCES `users` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `LUM_Role` (
`RoleID` int(10) unsigned NOT NULL,
`Name` enum('Deleted','Invalid','Valid') NOT NULL, 
PRIMARY KEY (`RoleID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
