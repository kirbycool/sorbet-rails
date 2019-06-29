# sorbet-rails
[![Gem Version](https://badge.fury.io/rb/sorbet-rails.svg)](https://badge.fury.io/rb/sorbet-rails)
[![Build Status](https://travis-ci.com/chanzuckerberg/sorbet-rails.svg?branch=master)](https://travis-ci.com/chanzuckerberg/sorbet-rails)
[![codecov](https://codecov.io/gh/chanzuckerberg/sorbet-rails/branch/master/graph/badge.svg)](https://codecov.io/gh/chanzuckerberg/sorbet-rails)

A set of tools to make the [Sorbet](https://sorbet.org) typechecker work with Ruby on Rails seamlessly.

This gem adds a few Rake tasks to generate Ruby Interface (RBI) files for dynamic methods generated by Rails. It also includes signatures for related Rails classes. The RBI files are added to a `sorbet/rails-rbi/` folder.

## Initial Setup

1. Follow the steps [here](https://sorbet.org/docs/adopting) to set up the latest version of Sorbet, up to being able to run `srb tc`.

2. Add `sorbet-rails` to your Gemfile and install them with Bundler.

```
# -- Gemfile --

gem 'sorbet-rails'
```

```sh
❯ bundle install
```

3. Generate RBI files for your routes and models:
```sh
❯ rake rails_rbi:routes
❯ rake rails_rbi:models
```

4. Automatically upgrade each file's typecheck level:
```sh
❯ srb rbi suggest-typed
```
Because we've generated RBI files for routes and models, a lot more files should be typecheckable now.

## RBI Files

### ActiveRecord

There is an ActiveRecord RBI file that we vendor with this gem. Sorbet picks up these vendored RBI files automatically. (Please make sure you are running the latest version.)

### Routes

This Rake task generates an RBI file defining `_path` and `_url` methods for all named routes in `routes.rb`:
```sh
❯ rake rails_rbi:routes
```
### Models

This Rake task generates RBI files for all models in the Rails application (all descendants of `ActiveRecord::Base`):
```sh
❯ rake rails_rbi:models
```
You can also regenerate RBI files for specific models:
```sh
❯ rake rails_rbi:models[ModelName,AnotherOne,...]
```
The generation task currently creates the following signatures:
- Column getters & setters
- Associations getters & setters
- Enum values, checkers & scopes
- Named scopes
- Model relation class

## Tips & Tricks

### Overriding generated signatures

`sorbet-rails` relies on Rails reflection to generate signatures. There are features this gem doesn't support yet such as [serialize](https://github.com/chanzuckerberg/sorbet-rails/issues/49) and [attribute custom types](https://github.com/chanzuckerberg/sorbet-rails/issues/16). The gem also doesn't know the signature of any methods you have overridden. However, it is possible to override the signatures that `sorbet-rails` generates.

For example, here is how to override the signature for a method in a model:

```ruby
# -- app/models/model_name.rbi --

# typed: strong
class ModelName
  sig { returns(T::Hash[...]) }
  def field_name; end

  sig { params(obj: T::Hash[....]).void }
  def field_name=(obj); end
end
```

### `find`, `first` and `last`

These 3 methods can either return a single nilable record or an array of records. Sorbet does not allow us to define multiple signatures for a function ([except stdlib](https://github.com/chanzuckerberg/sorbet-rails/issues/18)). It doesn't support defining one function signature that has varying returning value depending on the input parameter type. We opt to define the most commonly used signature for these methods, and monkey-patch new functions for the secondary use case.

In short:
- Use `find`, `first` and `last` to fetch a single record.
- Use `find_n`, `first_n`, `last_n` to fetch an array of records.

### `find_by_<attributes>`, `<attribute>_changed?`, etc.

Rails supports dynamic methods based on attribute names, such as `find_by_<attribute>`, `<attribute>_changed?`, etc. They all have static counterparts. Instead of generating all possible dynamic methods that Rails support, we recommend to use of the static version of these methods instead (also recommended by RuboCop).

Following are the list of attribute dynamic methods and their static counterparts. The static methods have proper signatures:
- `find_by_<attributes>` -> `find_by(<attributes>)`
- `find_by_<attributes>!` -> `find_by!(<attributes>)`
- `<attribute>_changed?` -> `attribute_changed?(<attribute>)`
- `saved_change_to_<attribute>?` -> `saved_change_to_attribute?(<attribute>)`

### `after_commit` and other callbacks

Consider converting `after_commit` callbacks to use instance method functions. Sorbet doesn't support binding an optional block with a different context. Because of this, when using a callback with a custom block, the block is evaluated in the wrong context (Class-level context). Refer to [this page](https://api.rubyonrails.org/classes/ActiveRecord/Callbacks.html) for a full list of callbacks available in Rails.

Before:
```ruby
after_commit do ... end
```
After:
```ruby
after_commit :after_commit
def after_commit
  ...
end
```

If you wanted to make these changes using [Codemod](https://github.com/facebook/codemod), try these commands:
```shell
# from methods like after_commit do <...> end
❯ codemod -d app/models/ --extensions rb \
  '(\s*)(before|after)_(validation|save|create|commit|find|initialize|destroy) do' \
  '\1\2_\3 :\2_\3\n\1def \2_\3'

# from methods like after_commit { <...> }
❯ codemod -d app/models/ --extensions rb \
  '(\s*)(before|after)_(validation|save|create|commit|find|initialize|destroy) \{ (.*) \}' \
  '\1\2_\3 :\2_\3\n\1def \2_\3\n\1\1\4\n\1end'
```
Note that Codemod's preview may show that the indentation is off, but it works.

### Look for `# typed: ignore` files

Because Sorbet's initial setup tries to flag files at whichever typecheck level generates 0 errors, there may be files in your repository that are `# typed: ignore`. This is because sometimes Rails allows very dynamic code that Sorbet does not believe it can typecheck.

It is worth going through the list of files that is ignored and resolve them (and auto upgrade the types of other files; see [initial setup](#initial-setup) above). Usually this will make many more files able to be typechecked.

## Contributing

Contributions and ideas are welcome! Please see [our contributing guide](CONTRIBUTING.md) and don't hesitate to open an issue or send a pull request to improve the functionality of this gem.

This project adheres to the Contributor Covenant [code of conduct](https://github.com/chanzuckerberg/.github/tree/master/CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to opensource@chanzuckerberg.com.

## License

[MIT](https://github.com/chanzuckerberg/sorbet-rails/blob/master/LICENSE)
