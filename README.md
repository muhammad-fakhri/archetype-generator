# archetype-generator

_archetype-generator_ is a script for creating project blueprints (aka archetypes) in go language. Created based on open-source project go-archetype

## How to use

    cd your-work-dir
    git clone https://github.com/muhammad-fakhri/archetype-generator
    configure parameters.yaml, setup project_name, project_repo_path, and service parameter
    make init
    new project will be generated at /project_name

## Transformers

There are two types of transformers: the **include** and **replace** transformers.

### The _include_ transformer

The include transformer allows inclusion or exclusion of whole files as well as parts of files in the generated project. A simple example: you ask then user whether to include a README file and based on the answer you include or exlude this entire file.

#### Including or exluding whole files

All files that pass the global ignore filter are included by default. Unless one or more of the _include_ rules with an empty `region_marker` applies to them, in which case the files are included only if the condition evaluates to true.

Condition is a go template condition as can be used in an `{{if}}` expression. As such a simple boolean is expressed as simply `.var` where `var` is typically a user input.

For example with the following user input:

```yml
inputs:
  - id: IncludeReadme
    text: Would you like to include the readme file?
    type: yesno
```

It is possbible to define the following include transformer:

```yml
transformations:
  - name: include the readme file
    type: include
    region_marker: # When there's no marker, the entire file(s) is included
    condition: .IncludeReadme
    files: ['README.md']
```

Note that when there's no `region_marker` that simply means that the entire file is included/excluded based on the user's input.

More sophisticated expresions could also be utilized, such as boolean algebra, using `and .x .y`, `or .x .y` etc (`x` and `y` are user inputs). For a complete reference, see [go templates](https://golang.org/pkg/text/template/).

#### Don't forget the dot `.`

Keep in mind that go templates require a dot (`.`) to prepend a value. So when utilizing user input, for example such as `IncludeReadme` be sure to prepend the dot, e.g. `.IncludeReadme` whenever used in conditions or replacements.

One caveat to that is that for simplicity archetype-generator allows dot-less conditions when they are very simple, e.g. only `variable`, such as `IncludeReadme`. So the following conditions are actually equivalent:

```
condition: .IncludeReadme
```

and

```
condition: IncludeReadme # No dot here
```

This is done in order to simplify the simple single-operand conditions. However, with more complex conditions be sure to prepend the dot.
For example the following condition is valid where x and y are user inputs:

```
condition: and .x .y
```

But the following is not valid:

```
condition: and x y # Not valid. x and y need to be prepended by a dot .
```

#### Including or exluding parts of files

Sometimes it's useful to conditionally include or exlude parts of files and not the entire files. To do this we utilize special region markers.

Example:

```go
const (
	.....

    // BEGIN __INCLUDE_EXAMPLE__
	BaseSystemConfigPath = "/v1/config"
	// END __INCLUDE_EXAMPLE__
)
```

The includes `example` are only required in cases where the user selected to add examples to the project.

The corresponding transformations.yml file sections are:

```yml
inputs:
  - id: include_db_sql
    text: Should db sql functionality be included?
    type: yesno

transformations:
  - name: include db sql - functionality
    type: include
    region_marker: __INCLUDE_DB_SQL__
    condition: .include_db_sql
    files: ['**']
```

To summarize, in cases where you'd like to include or exlude just parts of files (and not the entire file), you use special _region markers_ inside the source code file. These region markers are simply comments in Go.

### The _replace_ transformer

This transformer performs a search and replace functionality. For example you might ask the user for the project name and then replace the generic template project name with the user's provided name

Example:

```yml
inputs:
  - id: project_name
    text: What is the project name? (e.g. my-awesome-go-project)
    type: text

transformations:
  - name: project name
    type: replace
    pattern: archetype-be
    replacement: '{{ .project_name }}'
    files: ['**']
```

### Tips

A list of useful tips.

#### Always ignore

To always exclude some parts of the output regardless of user input, do as follows:

```yml
transformers:
  - name: do not include template code in the final output
    type: include
    region_marker: __DO_NOT_INCLUDE__
    condition: false
    files: ['**']
```

And then in your source file(s):

```
# BEGIN __DO_NOT_INCLUDE__
... Code that should neven be included in the final output, such as
... templating specific scripts, makefiles etc
# END __DO_NOT_INCLUDE__
```

#### Conditional replace

Sometimes you need to conditionally replace a pattern. The condition may depend on user input. For example you may ask the user whether they'd like to includ gRPC functionality in the project or not and based on that render a different makefile.

Since the underlying rendering engine uses [go templates](https://golang.org/pkg/text/template/) it is possible to utilize the following condition:

```
{{ if .include_grpc }}build: build-grpc{{ else }}build:{{end}}
```

This condition will render `build:` if `.include_grpc` is false and `build: build-grpc` if `.include_grpc` is true. `include_grpc` is a user input in this case.

The complete example would look as follows then:

```yml
inputs:
  - id: include_grpc
    text: Should gRPC functionality be included?
    type: yesno
transformations:
  - name: build with grpc or not
    type: replace
    pattern: 'build: build-grpc'
    replacement: '{{ if .include_grpc }}build: build-grpc{{ else }}build:{{end}}'
    files: ['Makefile']
```

#### Change to CamelCase

If you have a string that you'd like to change to CamelCase, for example `my-project`, first convert to snake_case and then to CamelCase. This is unfortunately a limitation of sprig.

Example:

```
replacement: "{{ .name | snakecase | camelcase }}"
```

Changing to camelCase where the first letter is lowercased is even more ticky, but here goes:

```
replacement: "{{ .name | snakecase | camelcase | swapcase | title | swapcase }}"
```

Yeah it works...

## Order of execution

Transformations are executed by the order they appear inside the transformations.yml file. The output of the first transformation is then piped into the input of the second transformation and so forth.
That means that the order is important such that if you're pattern needs to match certain text, you need to make sure that no previous transformation had changed this text. That's why it's wise to start with the more specific replacements and then move on to the more generic replacements.

Example:

```yml
transformations:
  - name: project long description
    type: replace
    pattern: Use archetype-generator to transform project archetypes into existing live projects
    replacement: '{{ wrap 80 .ProjectDescription }}'
    files: ['cmd/root.go']
  - name: project name
    type: replace
    pattern: archetype-be
    replacement: '{{ .ProjectName }}'
    files: ['*.go', '**/*.go']
```

`project long description` should be placed before `project name`. If it weren't so then after applying ProjetName replacement on all occurences of the string `"archetype-generator"` then the sentence `"Use archetype-generator to transform project archetypes into existing live projects"` would have become `"Use my-project-name to transform project archetypes into existing live projects"` and then the replacement would not have been matched.

## Before and After

The `before` and `after` hooks allows you to run arbitrary shell command just before running all transformations or just after then.

They are provided with useful context that can be used in the actual command, which includes:

- `source` (Used as `{{ .source }}`)
- `destination` (Used as `{{ .destination }}`)
- As well as all user inputs

## Operations and debugging

The view detailed logs, run with `LOG_LEVEL=debug`
