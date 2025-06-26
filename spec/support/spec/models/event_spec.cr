require "../spec_helper"

describe Event do
  it "wip" do
    Event::SaveOperation.create!(
      id: 1,
      type: 1,
      message: "This is a test event"
    )

    event = EventQuery.find(1)
    event.message.should eq "This is a test event"

    specific_find = AppDatabase.query_all(
      "SELECT * FROM events_p2025_06_22 LIMIT 1",
      as: Event,
    )
    specific_find.last.message.should eq "This is a test event"

    no_event = AppDatabase.query_all(
      "SELECT * FROM events_p2025_06_01 LIMIT 1",
      as: Event,
    )
    no_event.should be_empty
  end
end
