---
layout: post
title: Support MySQL native JSON data type in ActiveRecord (Rails) 4
tags: [mysql, data_types, rails]
category: mysql
last_modified_at: 2018-03-09 19:00:00
---

Mysql 5.7 added native support for JSON data type. This opens up several interesting possibilities, but it's not natively supported in Rails 4 (only in v5).

I've released a gem, [JSON on Rails](https://github.com/saveriomiroddi/json_on_rails), for supporting this functionality on Rails 4.

This article describes how the gem works, for those interested in the inner workings, or who want to implement the functionality by themselves.

## Introduction

In Rails 5, using an attribute backed by a JSON column is fairly easy:

```ruby
serialize :my_json_attribute, JSON
```

This is not possible in Rails 4, as it doesn't natively support the JSON MySQL data type, and deserializes the value to a flat string.

The source files used for reference, are:

```sh
/path/to/activerecord_gem/lib/active_record/attributes.rb
/path/to/activerecord_gem/lib/active_record/type/value.rb
/path/to/activerecord_gem/lib/active_record/type/mutable.rb
```

Note that "ActiveRecord 4/5" is a more precise description, but for simplicity, I'll just use "Rails".

## Implementation

In the basic form, implementing a new data type consist of coding the rules for translating to/from database and user.

As first step, create this initializer (e.g. `config/initializers/json_data_type.rb`):

```ruby
module ActiveRecord
  module Type
    class Json < Type::Value
      include Type::Mutable

      def type
        :json
      end

      def type_cast_for_database(value)
        case value
        when Array, Hash
          value.to_json
        when nil
          nil
        else
          raise ArgumentError, "Invalid JSON root data type: #{value.class} (only Hash/Array/nil supported)"
        end
      end

      private

      def cast_value(value)
        if value.is_a?(::String)
          JSON.parse(value)
        else
          raise "Unexpected JSON data type when loading from the database: #{value.class}"
        end
      end
    end
  end
end
```

add a field in the ActiveRecord desired model:

```ruby
class MyModel
  serialize :my_json_attribute, ActiveRecord::Type::Json.new
end
```

and create a migration:

```ruby
class AddMyJsonAttributeToMyModel < ActiveRecord::Migration
  def change
    add_column :my_models, :my_json_attribute, :json
  end
end
```

Now I'll break it down; the gotchas will be explained in the next section.

First we define the type:

```ruby
def type
  :json
end
```

this will uniquely identify the data type; for example, it allows Rails to create a migration using the standard form (see above).

Then we need to define the type casting methods. Rails supports more granular casting, but for simple data types, we just need to define two methods (here in edited format:

```ruby
include Type::Mutable

def type_cast_for_database(value)
  case value
  when Array, Hash
    value.to_json
  when ::String, nil
    value
  else
    raise ArgumentError, "Invalid data type for JSON serialization: #{value.class}  (only Hash/Array/nil supported)"
  end
end

def cast_value(value)
  if value.is_a?(::String)
    JSON.parse(value)
  else
    raise "Unexpected JSON data type when loading from the database: #{value.class}"
  end
end
```

The first method, `type_cast_for_database`, performs the conversion from the in-memory value to the value to be sent to the database.  
We'll simply convert the Array/Hash to a JSON string (note that `#to_json` returns a String). We also support String values, which can be used to represent a serialized JSON document (they will be internally converted by MySQL, and deserialized again by the ActiveRecord into the Ruby class.)

The second, `cast_value`, performs the conversion from database-read values. Only String are received in this case.

There is a crucial design decision: since symbols are a Ruby concept not included in JSON, it's important to decide what to do with the hash keys passed (other literal values also suffer this problem, but it can be somewhat ignored, at least, in the basic form). In this case, we ignore symbols, which are converted to Strings, but options are possible, depending on the requirements, e.g. raising an error when an unexpected key type is received, using HashWithIndifferentAccess, or using (deep) keys conversion.

The `include Type::Mutable` module automatically adds a method (`changed_in_place?`) which detects differences between the old and new values when persisting the value.

Specifying the attribute in a model is trivial (more on this in the gotchas section):

```ruby
class MyModel < ActiveRecord::Base
  serialize :my_json_attribute, ActiveRecord::Type::Json.new
end
```

and so is creating the migration:

```ruby
add_column :my_models, :my_json_attribute, :json
```

result:

```sql
mysql> DESCRIBE my_models;
+-------------------+---------+------+-----+---------+----------------+
| Field             | Type    | Null | Key | Default | Extra          |
+-------------------+---------+------+-----+---------+----------------+
| id                | int(11) | NO   | PRI | NULL    | auto_increment |
| my_json_attribute | json    | YES  |     | NULL    |                |
+-------------------+---------+------+-----+---------+----------------+
```

The `json_on_rails` gem, which uses the same base structure while also adding the JSON support at `mysql2` driver level, makes it possible to use `ActiveRecord::Store` backed by the native MySQL JSON data type:

```ruby
class MyModel < ActiveRecord::Base
  store_accessor :my_json_column, :my_attribute, :my_other_attribute
end

MyModel.create!(my_attribute: [1, 2, 3])
```

```sql
mysql> SELECT my_json_column FROM my_models;
------------------------------+
| my_json_column              |
+-----------------------------+
| {"my_attribute": [1, 2, 3]} |
+-----------------------------+
```

### MySQL JSON bugs/limitations

There are a couple of gotchas to take care of.

#### MySQL JSON SELECT bug (IMPORTANT!)

MySQL version up to at least 5.7.12 have a serious JSON bug.

In some cases, queries using DISTINCT on VARCHAR and JSON columns, will not perform the deduplication, resulting in duplicate rows being returned, if there are any.

This has been fixed between 5.7.13 and 5.7.18 (I couldn't find the related enty in the release notes), therefore, MySQL 5.7 users are urged to upgrade to a recent version if they use JSON columns.

#### MySQL decimal normalization

MySQL (up to 8.0.3, included) will normalize decimal numbers with zero fractional (e.g. `5.0`) to integers, therefore, changing the data type on save.

See [relevant bug](https://bugs.mysql.com/bug.php?id=88230).

#### Default value

MySQL doesn't support default values for JSON columns, so it will need to be set at Rails level.

## Conclusion

While a company is taking the time to migrate to Rails 5, by using the gem or implementing the custom data type, it's currently possible to work smoothly with the JSON data type, opening up several interesting possibilities.

## Extra: References on working with JSON in MYSQL 5.7

Some introductory references on JSON in MySQL 5.7:

- [MySQL 5.7 Introduces a JSON Data Type](https://lornajane.net/posts/2016/mysql-5-7-json-features)
- [How to Use JSON Data Fields in MySQL Databases](https://www.sitepoint.com/use-json-data-fields-mysql-databases/)
- [JSON document fast lookup with MySQL 5.7](https://www.percona.com/blog/2016/03/07/json-document-fast-lookup-with-mysql-5-7/)

*Edited 2018-02-14: Added JSON DISTINCT bug information*
*Edited 2018-02-11: Added gem reference, and minor code updates*
