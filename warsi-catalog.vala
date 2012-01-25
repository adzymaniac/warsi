/* warsi-catalog.vala
 *
 * Copyright (C) 2011  Aji Kisworo Mukti <adzy@di.blankon.in>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

using GLib;
using Gee;

private const string PACKAGES_DIR         = "/var/lib/apt/lists";
private const string STATUS_PACKAGES      = "/var/lib/dpkg/status";
private const long MAX_REC_PER_PAGE       = 100;

public struct PackageRow {
    public string name;
    public string version;
    public string offset;
    public int64 repository;
}

public struct PackageList {
    public string name;
    public string version;
    public string offset;
    public string repository;
}

public struct PackageInfo {
    public string priority;
    public string section;
    public string installed_size;
    public string maintainer;
    public string original_maintainer;
    public string architecture;
    public string depends;
    public string filename;
    public string size;
    public string md5sum;
    public string sha1;
    public string sha256;
    public string description;
    public string bugs;
    public string origin;
}

public class WarsiCatalog : GLib.Object {
    
    private long offset;

    public WarsiCatalog () {

    }

      public void synchronize () throws WarsiCatalogError {
            var directory     = File.new_for_path (PACKAGES_DIR);
            var enumerator     = directory.enumerate_children (FILE_ATTRIBUTE_STANDARD_NAME, 0);

            FileInfo file_info;
            WarsiDatabase.instance().prepare ();

            while ((file_info = enumerator.next_file ()) != null) {
                if ("Packages" in file_info.get_name ()) {
                    var file = File.new_for_path ("%s/%s".printf (PACKAGES_DIR, file_info.get_name ()));
             
                    if (!file.query_exists (null)) {
                        throw new WarsiCatalogError.CATALOG_OPEN_AVAILABLE_ERROR ("File '%s' doesn't exist.\n", file.get_path ());
                    }        

                    PackageRow row = PackageRow ();
                    var timestamp = new DateTime.now_local ();
                    var repo_id = WarsiDatabase.instance().insert_repository (file_info.get_name (), timestamp.to_string ());
                    row.repository = repo_id;

                    try {
                        var in_stream = new DataInputStream (file.read (null));
                        string line;
                        offset = 0;

                        while ((line = in_stream.read_line (null, null)) != null) {
                            if (line[0] != ' ') {
                                var str = line.split(": ");

                                switch (str[0]) {
                                    case "Package":
                                        row.name = str[1];
                                        break;
                                    case "Version":
                                        row.version = str[1];
                                        break;
                                }
                            }

                            offset += line.length + 1;

                            if (line.length == 0) {
                                if (row.name.length != 0 && row.version.length != 0) {
                                    row.offset = ("%xld").printf ((uint)offset);
                                    WarsiDatabase.instance().insert (row);
                                }
                            }
                        }
                    } catch (WarsiCatalogError e) {
                        GLib.stderr.printf ("%s\n", e.message);
                    }
                }
            }
            WarsiDatabase.instance().save ();
    }

    public string list (string package = "", long start) throws WarsiCatalogError {
        string packages = "";
        bool need_comma = false;
        var packageslist = WarsiDatabase.instance().list (package, start, MAX_REC_PER_PAGE);
         
        packages += "[\n";
        foreach ( PackageList? packagelist in packageslist ) {
            if (need_comma) packages += ",\n";
            packages += " { 'name' : '%s',\n".printf (packagelist.name);
            packages += " 'version' : '%s',\n".printf (packagelist.version);
            packages += " 'offset' : '%s',\n".printf (packagelist.offset);
            packages += " 'repository' : '%s',\n".printf (packagelist.repository);
            need_comma = true;
        }
        packages += "]";
        return packages;
    }

    public long get_size () {
        return WarsiDatabase.instance().get_list_size ();
    }

    public string get_info (string name, string version) {
        uint8 buffer[1024];
        size_t bytes_read;

        var packagerow = WarsiDatabase.instance().get_info (name, version);

        var file = File.new_for_path ("%s/%s".printf (PACKAGES_DIR, packagerow.repository));
        var in_stream = file.read ();

        if (!file.query_exists (null)) {
           throw new WarsiCatalogError.CATALOG_OPEN_AVAILABLE_ERROR ("File '%s' doesn't exist.\n", file.get_path ());
        }

        in_stream.seek (0, SeekType.CUR);
        bool still_data = true;
        PackageInfo row = PackageInfo ();

        do {
            bytes_read = in_stream.read (buffer, null);
            var lines = (string) buffer;
            var cut_off = lines.index_of ("\n\n");

            if (cut_off > 0) {
                lines = lines.slice (0, cut_off);
            }
    
            if (bytes_read <= 0 || cut_off > 0) {
                still_data = false;
            }

            foreach (var line in lines.split ("\n")) {
                if (line[0] != ' ') {
                    var str = line.split(": ");

                    switch (str[0]) {
                        case "Priority":
                            row.priority = str[1];
                            break;
                        case "Section":
                            row.section = str[1];
                            break;
                        case "Installed-Size":
                            row.installed_size = str[1];
                            break;
                        case "Maintainer":
                            row.maintainer = str[1];
                            break;
                        case "Original-Maintainer":
                            row.original_maintainer = str[1];
                            break;
                        case "Architecture":
                            row.architecture = str[1];
                            break;
                        case "Depends":
                            row.depends = str[1];
                            break;
                        case "Filename":
                            row.filename = str[1];
                            break;
                        case "Size":
                            row.size = str[1];
                            break;
                        case "MD5sum":
                            row.md5sum = str[1];
                            break;
                        case "SHA1":
                            row.sha1 = str[1];
                            break;
                        case "SHA256":
                            row.sha256 = str[1];
                            break;
                        case "Description":
                            row.description = str[1];
                            break;
                        case "Bugs":
                            row.bugs = str[1];
                            break;
                        case "Origin":
                            row.origin = str[1];
                            break;
                    }
                } else {
                   row.description += "%s".printf ((string) line);
                }
            }
        } while (still_data);

        string package = "{ 'name' : '%s', 'version' : '%s', 'offset' : '%s', 'repository' : '%s', 'priority' : '%s', 'section' : '%s', 'installed_size' : '%s', 'maintainer' : '%s', 'original_maintainer' : '%s', 'architecture' : '%s', 'depends' : '%s', 'filename' : '%s', 'size' : '%s', 'md5sum' : '%s', 'sha1' : '%s', 'sha256' : '%s', 'description' : '%s', 'bugs' : '%s', 'origin' : '%s' }"
        .printf (packagerow.name, packagerow.version, packagerow.offset, packagerow.repository, row.priority, 
                 row.section, row.installed_size, row.maintainer, row.original_maintainer, row.architecture, 
                 row.depends, row.filename, row.size, row.md5sum, row.sha1, row.sha256, row.description, 
                 row.bugs, row.origin);

        return package;
    }

    public status () {

    }

    public update_available () {

    }

    public update_status () {

    }

    public list_favorit () {

    }

    public list_available () {

    }
}
