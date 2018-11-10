# This module add ability to define chain of steps
# which will be called in order.
# Every step is a method in the class which include this module.
# Every class receive state and immutable params.
#
# State is used to keep information which will be shared between
# steps. State should inherit from Chaintown::State.
# Steps are calls only when state is valid in other case invocation
# is stopped and moved to run steps defined as failed.
#
# We can add conditions to step by using *if* parameter.
# We can also nest steps.
#
# Example:
#
#   step :step1
#   step :step2, if: proc { |state, params| params[:run_step_2] }
#   step :step3 do
#     step :step4
#   end
#   failed_step :step5
#
module Chaintown
  module Chain
    extend ActiveSupport::Concern

    included do
      self.extend Chaintown::Steps

      attr_reader :state, :params
      delegate :steps, :failed_steps, to: :class
    end

    def initialize(state, params)
      @state, @params = state, params.freeze
    end

    def perform
      perform_steps(steps, failed_steps)
      state
    end

  private

    def perform_steps(steps, failed_steps)
      steps.each do |step|
        break unless state.valid?
        next unless step.if_condition.blank? || step.if_condition.call(state, params)
        perform_step(step)
      end
      unless state.valid?
        failed_steps.each do |step|
          next unless step.if_condition.blank? || step.if_condition.call(state, params)
          perform_step(step)
        end
      end
    end

    def perform_step(step)
      if step.steps.present?
        method(step.method_name).call do
          perform_steps(step.steps, step.failed_steps)
        end
      else
        method(step.method_name).call
      end
    end
  end
end