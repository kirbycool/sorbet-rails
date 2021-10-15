# typed: false
class AasmPlugin < SorbetRails::ModelPlugins::Base
  sig { override.params(root: Parlour::RbiGenerator::Namespace).void }
  def generate(root)
    return unless @model_class.include?(::AASM)

    @model_rbi = root.create_class(
      model_class_name
    )

    machine_store = AASM::StateMachineStore.fetch(@model_class, true)
    machine_names = machine_store.machine_names

    machine_names.each do |machine_name|
      add_machine_methods(machine_store.machine(machine_name))
    end
  end

  sig { params(machine: AASM::StateMachine).void }
  def add_machine_methods(machine)
    namespace = machine.config.namespace
    aasm_events = machine.events.values.map(&:name)
    aasm_states = machine.states.map(&:name)

    parameters = [
      ::Parlour::RbiGenerator::Parameter.new(
        '**params',
        type: "T.untyped",
      )
    ]

    # If you have an event like :bazify, you get these methods:
    # - `may_bazify?`
    # - `bazify`
    # - `bazify!`
    # - `bazify_without_validation!`
    aasm_events.each do |event|
      unless namespace.blank?
        event = "#{namespace}_#{event}"
      end

      @model_rbi.create_method(
        "may_#{event}?",
        return_type: 'T::Boolean'
      )

      @model_rbi.create_method(
        event.to_s,
        parameters: parameters,
        return_type: 'T::Boolean'
      )

      @model_rbi.create_method(
        "#{event}!",
        parameters: parameters,
        return_type: 'T::Boolean'
      )

      @model_rbi.create_method(
        "#{event}_without_validation!",
        parameters: parameters,
        return_type: 'T::Boolean'
      )
    end

    # - If you have a state like :baz, you get these methods:
    # - `baz?`
    aasm_states.each do |state|
      unless namespace.blank?
        state = "#{namespace}_#{state}"
      end

      @model_rbi.create_method(
        "#{state}?",
        return_type: 'T::Boolean'
      )
    end
  end
end
