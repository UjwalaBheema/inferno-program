# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310PractitionerSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Practitioner'

      description 'Verify that Practitioner resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCPR'

      requires :token
      conformance_supports :Practitioner
      delayed_sequence

      def validate_resource_item(resource, property, value)
        case property

        when 'name'
          value = value.downcase
          value_found = resolve_element_from_path(resource, 'name') do |name|
            name&.text&.start_with?(value) ||
              name&.family&.downcase&.include?(value) ||
              name&.given&.any? { |given| given.downcase.start_with?(value) } ||
              name&.prefix&.any? { |prefix| prefix.downcase.start_with?(value) } ||
              name&.suffix&.any? { |suffix| suffix.downcase.start_with?(value) }
          end
          assert value_found.present?, 'name on resource does not match name requested'

        when 'identifier'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'identifier.value') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'identifier on resource does not match identifier requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      def patient_ids
        @instance.patient_ids.split(',').map(&:strip)
      end

      @resources_found = false

      test :resource_read do
        metadata do
          id '01'
          name 'Server returns correct Practitioner resource from the Practitioner read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            Reference to Practitioner can be resolved and read.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Practitioner, [:read])

        practitioner_references = @instance.resource_references.select { |reference| reference.resource_type == 'Practitioner' }
        skip 'No Practitioner references found from the prior searches' if practitioner_references.blank?

        @practitioner_ary = practitioner_references.map do |reference|
          validate_read_reply(
            FHIR::Practitioner.new(id: reference.resource_id),
            FHIR::Practitioner,
            check_for_data_absent_reasons
          )
        end
        @practitioner = @practitioner_ary.first
        @resources_found = @practitioner.present?
      end

      test :validate_resources do
        metadata do
          id '02'
          name 'Practitioner resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitioner'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Practitioner', delayed: true)
        test_resources_against_profile('Practitioner')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/identifier-use',
            path: 'identifier.use'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/identifier-type',
            path: 'identifier.type'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/name-use',
            path: 'name.use'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/administrative-gender',
            path: 'gender'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @practitioner_ary)
          rescue Inferno::Terminology::UnknownValueSetException => e
            warning do
              assert false, e.message
            end
            invalid_bindings = []
          end
          invalid_bindings.each { |invalid| invalid_binding_resources << "#{invalid[:resource]&.resourceType}/#{invalid[:resource].id}" }
          invalid_binding_messages.concat(invalid_bindings.map { |invalid| invalid_binding_message(invalid, binding_def) })
        end
        assert invalid_binding_messages.blank?, "#{invalid_binding_messages.count} invalid required binding(s) found in #{invalid_binding_resources.count} resources:" \
                                                "#{invalid_binding_messages.join('. ')}"

        bindings.select { |binding_def| binding_def[:strength] == 'extensible' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @practitioner_ary)
            binding_def_new = binding_def
            # If the valueset binding wasn't valid, check if the codes are in the stated codesystem
            if invalid_bindings.present?
              invalid_bindings = resources_with_invalid_binding(binding_def.except(:system), @practitioner_ary)
              binding_def_new = binding_def.except(:system)
            end
          rescue Inferno::Terminology::UnknownValueSetException, Inferno::Terminology::ValueSet::UnknownCodeSystemException => e
            warning do
              assert false, e.message
            end
            invalid_bindings = []
          end
          invalid_binding_messages.concat(invalid_bindings.map { |invalid| invalid_binding_message(invalid, binding_def_new) })
        end
        warning do
          invalid_binding_messages.each do |error_message|
            assert false, error_message
          end
        end
      end

      test 'Every reference within Practitioner resource is valid and can be read.' do
        metadata do
          id '03'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Practitioner, [:search, :read])
        skip_if_not_found(resource_type: 'Practitioner', delayed: true)

        validated_resources = Set.new
        max_resolutions = 50

        @practitioner_ary&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
