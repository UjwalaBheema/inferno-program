# frozen_string_literal: true

require File.expand_path '../test_helper.rb', __dir__

describe FHIR::Models do
  describe '#from_contents' do
    it 'should set source_contents' do
      bundle_json = File.read('test/fixtures/bundle_1.json')
      bundle_resource = FHIR.from_contents(bundle_json)
      bundle_resource.entry.each do |entry|
        assert entry.source_contents.present?, "entry.source_contents not populated for #{entry}"
        assert_instance_of String, entry.source_contents
        assert entry.resource.source_contents.present?, "entry.resource.source_contents not populated for #{entry}"
        assert_instance_of String, entry.resource.source_contents
      end
    end

    it 'should preserve primitive extensions in source_contents' do
      procedure_json = File.read('test/fixtures/procedure_primitive_extension.json')
      procedure_resource = FHIR.from_contents(procedure_json)
      assert procedure_resource.source_contents.include?('_performedDateTime'), 'Primitive extension key was lost'
      assert procedure_resource.source_contents.include?('http://hl7.org/fhir/StructureDefinition/data-absent-reason'), 'Primitive extension URL was lost'
    end
  end

  describe '#initialize' do
    it 'should set source_contents' do
      bundle_resource = FHIR::Bundle.new(
        {
          resourceType: 'Bundle', entry:
          [
            { resource: { resourceType: 'Patient', id: 'a' } },
            { resource: { resourceType: 'Patient', id: 'b' } }
          ]
        }
      )
      bundle_resource.entry.each do |entry|
        assert entry.source_contents.present?, "entry.source_contents not populated for #{entry}"
        assert_instance_of String, entry.source_contents
        assert entry.resource.source_contents.present?, "entry.resource.source_contents not populated for #{entry}"
        assert_instance_of String, entry.resource.source_contents
      end
    end
  end
end
