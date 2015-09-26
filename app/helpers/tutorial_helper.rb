module TutorialHelper

  @tc = TutorialController.new

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  DT   = @tc.datetime
  JCFT = @tc.jcft
  MEAN = @tc.mean
  EQC  = @tc.eqc
  ELN  = @tc.ecliplon
  RA   = @tc.ra
  FIN  = @tc.final

end