# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::EucalyptusCloud::Cloud do

  describe "creating via provider" do

    it "can be created using Bosh::Cloud::Provider" do
      cloud = Bosh::Clouds::Provider.create(:eucalyptus, mock_cloud_options)
      cloud.should be_an_instance_of(Bosh::EucalyptusCloud::Cloud)
    end

  end

end
