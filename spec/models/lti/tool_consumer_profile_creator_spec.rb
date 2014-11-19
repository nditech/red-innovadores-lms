require 'spec_helper'

module Lti
  describe ToolConsumerProfileCreator do

    let(:root_account) { mock('root account', lti_guid: 'my_guid') }
    let(:account) { mock('account', root_account: root_account) }
    let(:tcp_url) {'http://example.instructure.com/tcp/uuid'}
    subject { ToolConsumerProfileCreator.new(account, tcp_url, 'example.instructure.com', 'account') }

    describe '#create' do

      it 'creates the tool consumer profile' do
        profile = subject.create
        expect(profile.lti_version).to eq 'LTI-2p0'
        expect(profile.product_instance).to be_an_instance_of IMS::LTI::Models::ProductInstance
      end

      it 'creates the product instance' do
        product_instance = subject.create.product_instance
        expect(product_instance.guid).to eq 'my_guid'
        expect(product_instance.product_info).to be_an IMS::LTI::Models::ProductInfo

      end

      it 'creates the product info' do
        product_info = subject.create.product_instance.product_info
        expect(product_info.product_name.default_value).to eq 'Canvas by Instructure'
        expect(product_info.product_version).to eq 'none'
        expect(product_info.product_family).to be_a IMS::LTI::Models::ProductFamily
      end

      it 'creates the product family' do
        product_family = subject.create.product_instance.product_info.product_family
        expect(product_family.code).to eq 'canvas'
        expect(product_family.vendor).to be_a IMS::LTI::Models::Vendor

      end

      it 'creates the vendor' do
        vendor = subject.create.product_instance.product_info.product_family.vendor
        expect(vendor.code).to eq 'https://instructure.com'
        expect(vendor.vendor_name.default_value).to eq 'Instructure'
        expect(vendor.vendor_name.key).to eq 'vendor.name'
        expect(vendor.timestamp.to_i).to eq Time.parse('2008-03-27 00:00:00 -0600').to_i
      end

      it 'creates the registration service' do
        profile = subject.create
        reg_srv = profile.service_offered.find {|srv| srv.id.include? 'ToolProxy.collection'}
        expect(reg_srv.id).to eq "#{tcp_url}#ToolProxy.collection"
        expect(reg_srv.endpoint).to eq 'https://example.instructure.com/api/lti/accounts/{account_id}/tool_proxy'
        expect(reg_srv.type).to eq 'RestService'
        expect(reg_srv.format).to eq ["application/vnd.ims.lti.v2.toolproxy+json"]
        expect(reg_srv.action).to include 'POST'

      end

      it 'add the basic_launch capability' do
        expect(subject.create.capability_offered).to include 'basic-lti-launch-request'
      end

    end
  end
end