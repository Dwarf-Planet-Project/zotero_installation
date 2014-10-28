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
`userID` int(10) unsigned NOT NULL,
`id` int(10) unsigned NOT NULL,
`dateModified` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
`lifetime` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00', 
KEY (`userID`),
KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user_email` (
`userID` int(10) unsigned NOT NULL,
`email` varchar(255) NOT NULL,
PRIMARY KEY (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `storage_institutions` (
`storageQuota` mediumint(8) unsigned NOT NULL,
`domain` varchar(255) NOT NULL,
`institutionID` int(10) unsigned NOT NULL,
PRIMARY KEY (`institutionID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `storage_institution_email` (
`email` varchar(255) NOT NULL,
`institutionID` int(10) unsigned NOT NULL,
PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `users` (
`userID` int(10) unsigned NOT NULL,
`username` varchar(255) NOT NULL,
`password` char(40) NULL,
UNIQUE KEY (`username`),
UNIQUE KEY (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `users_meta` (
`userID` int(10) unsigned NOT NULL,
`metaKey` varchar(20) NOT NULL,
`metaValue` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `LUM_User` (
`UserID` int(10) unsigned NOT NULL,
`RoleID` int(10) unsigned NOT NULL,
PRIMARY KEY (`UserID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `LUM_Role` (
`RoleID` int(10) unsigned NOT NULL,
`Name` varchar(20) NOT NULL,
PRIMARY KEY (`RoleID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
