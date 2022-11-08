---
layout: post
title: "SQLIte database file format diagrams"
tags: [databases,data_types,indexes,storage]
last_modified_at: 2022-11-09 00:35:36
---

During my [CodeCrafters](https://codecrafters.io) SQLite project, I've found the SQLite database file format document to be rather complete, but nonetheless, for a variety of reasons, hard to use.

In this article I present easy to read diagrams, that one can refer to while developing the exercises.

Content:

- [Introduction](/SQLIte-database-file-format-diagrams#introduction)
- [Index interior page](/SQLIte-database-file-format-diagrams#index-interior-page)
- [Index leaf page](/SQLIte-database-file-format-diagrams#index-leaf-page)
- [Table interior page](/SQLIte-database-file-format-diagrams#table-interior-page)
- [Table leaf page](/SQLIte-database-file-format-diagrams#table-leaf-page)

## Introduction

The fields described in the diagrams are a subset of the full specification - they're only those required to solve the problems of the CodeCrafters project; some concepts are therefore skipped, e.g. overflow.

The green background color indicates fields that are shared across different page types; if fields of a child are highlighted, but not the parent, it means that the child itself is optional, but when present, its highlighted fields are mandatory.

The diagram files can be found in the [related repository](https://github.com/64kramsystem/codecrafters_resources) of mine; the reference format is [PlantUML](https://plantuml.com/).

If you find any error, please [contact me]({{ "/about/#contact-me" }}), or add a comment (below)!

## Index interior page

![Index interior page]({{ "/images/2022-11-09-SQLIte-database-file-format-diagrams/index_interior_page.svg" }})

## Index leaf page

![Index leaf page]({{ "/images/2022-11-09-SQLIte-database-file-format-diagrams/index_leaf_page.svg" }})

## Table interior page

![Table interior page]({{ "/images/2022-11-09-SQLIte-database-file-format-diagrams/table_interior_page.svg" }})

## Table leaf page

![Table leaf page]({{ "/images/2022-11-09-SQLIte-database-file-format-diagrams/table_leaf_page.svg" }})
