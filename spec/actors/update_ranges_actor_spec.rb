require 'rails_helper'

RSpec.describe Trifle::UpdateRangesActor do

  let(:canvases) { 5.times.map do FactoryGirl.create(:iiifimage) end }
  let(:top_range) {
    FactoryGirl.create(:iiifrange, ordered_members: canvases + [
      FactoryGirl.create(:iiifrange, ordered_members: [
        canvases[0], canvases[1], canvases[2],
        FactoryGirl.create(:iiifrange, ordered_members: [canvases[0], canvases[1]]),
        FactoryGirl.create(:iiifrange, ordered_members: [canvases[2]])
      ] ),
      FactoryGirl.create(:iiifrange, ordered_members: [canvases[3], canvases[4]] ),
    ])
  }
  
  let(:range1) { top_range.sub_ranges[0] }
  let(:range11) { range1.sub_ranges[0] }
  let(:range12) { range1.sub_ranges[1] }
  let(:range2) { top_range.sub_ranges[1] }

  let(:ranges_json) { manifest.iiif_ranges(2).map do |r| JSON.parse(r.to_json) end }
  let(:top_range_json) {ranges_json.find do |r| r['@id'].end_with?("/#{top_range.id}") end}
  let(:range1_json) {ranges_json.find do |r| r['@id'].end_with?("/#{range1.id}") end}
  let(:range11_json) {ranges_json.find do |r| r['@id'].end_with?("/#{range11.id}") end}
  let(:range12_json) {ranges_json.find do |r| r['@id'].end_with?("/#{range12.id}") end}
  let(:range2_json) {ranges_json.find do |r| r['@id'].end_with?("/#{range2.id}") end}
    
  let(:canvas_uris) { top_range_json['canvases'] }

  let(:manifest) { FactoryGirl.create(:iiifmanifest, ordered_members: canvases + [top_range] ) }
  
  let(:actor_options) { {} }
  
  let(:actor) {
    # Need reload. json generation uses from_solr! which makes things read_only.
    Trifle::UpdateRangesActor.new(manifest.reload, nil, actor_options) 
  }
  
  let(:result) {
    actor.update_ranges(ranges_json)
    manifest.reload.ranges.first
  }
  
  let(:res_top_range) { result }
  let(:res_range1) { res_top_range.sub_ranges.find do |r| r.id == range1.id end }
  let(:res_range11) { res_range1.sub_ranges.find do |r| r.id == range11.id end }
  let(:res_range12) { res_range1.sub_ranges.find do |r| r.id == range12.id end }
  let(:res_range2) { res_top_range.sub_ranges.find do |r| r.id == range2.id end }

  it "created manifest correctly" do
    expect(manifest.ranges.map(&:id)).to eql([top_range.id])
    expect(top_range.canvases.count).to eql(5)
    expect(top_range.sub_ranges.map(&:id)).to eql([range1.id, range2.id])
    expect(range1.canvases.count).to eql(3)
    expect(range1.sub_ranges.map(&:id)).to eql([range11.id, range12.id])
    expect(range11.canvases.count).to eql(2)
    expect(range11.sub_ranges.count).to eql(0)
    expect(range12.canvases.count).to eql(1)
    expect(range12.sub_ranges.count).to eql(0)
    expect(range2.canvases.count).to eql(2)
    expect(range2.sub_ranges.count).to eql(0)
  end

  it "deletes ranges" do
    range1_json['ranges'].delete(range11_json['@id'])
    ranges_json.delete(range11_json)
    
    expect(res_top_range.canvases.count).to eql(5)
    expect(res_top_range.sub_ranges.map(&:id)).to eql([range1.id, range2.id])
    expect(res_range1.canvases.count).to eql(3)
    expect(res_range1.sub_ranges.map(&:id)).to eql([range12.id])
    expect(res_range11).to be_nil
    expect { Trifle::IIIFRange.find(range11.id) } .to raise_error(Ldp::Gone)
    expect(res_range12.canvases.count).to eql(1)
    expect(res_range12.sub_ranges.count).to eql(0)
    expect(res_range2.canvases.count).to eql(2)
    expect(res_range2.sub_ranges.count).to eql(0)
  end
  
  it "deletes canvases" do
    range11_json['canvases'].delete(range11_json['canvases'].first)

    expect(res_top_range.canvases.count).to eql(5)
    expect(res_top_range.sub_ranges.map(&:id)).to eql([range1.id, range2.id])
    expect(res_range1.canvases.count).to eql(3)
    expect(res_range1.sub_ranges.map(&:id)).to eql([range11.id, range12.id])
    expect(res_range11.canvases.map(&:id)).to eql([canvases[1].id])
    expect(res_range11.sub_ranges.count).to eql(0)
    expect(res_range12.canvases.count).to eql(1)
    expect(res_range12.sub_ranges.count).to eql(0)
    expect(res_range2.canvases.count).to eql(2)
    expect(res_range2.sub_ranges.count).to eql(0)
  end
    
  it "moves ranges" do 
    range1_json['ranges'].delete(range12_json['@id'])
    range1_json['canvases'].delete(canvas_uris[2])
    range2_json['ranges']=[range12_json['@id']]
    range2_json['canvases'].unshift(canvas_uris[2])
    
    expect(res_top_range.canvases.count).to eql(5)
    expect(res_top_range.sub_ranges.map(&:id)).to eql([range1.id, range2.id])
    expect(res_range1.canvases.map(&:id)).to eql([canvases[0].id, canvases[1].id])
    expect(res_range1.sub_ranges.map(&:id)).to eql([range11.id])
    expect(res_range11.canvases.map(&:id)).to eql([canvases[0].id, canvases[1].id])
    expect(res_range11.sub_ranges.count).to eql(0)
    expect(res_range12).to be_nil
    moved_range12 = res_range2.sub_ranges.find do |r| r.id == range12.id end
    expect(moved_range12.canvases.count).to eql(1)
    expect(moved_range12.sub_ranges.count).to eql(0)
    expect(res_range2.canvases.map(&:id)).to eql([canvases[2].id, canvases[3].id, canvases[4].id])
    expect(res_range2.sub_ranges.map(&:id)).to eql([range12.id])
  end
  
  it "moves canvases" do
    range1_json['canvases'].delete(canvas_uris[2])
    range12_json['canvases'].delete(canvas_uris[2])
    range2_json['canvases'].unshift(canvas_uris[2])
    
    expect(res_top_range.canvases.count).to eql(5)
    expect(res_top_range.sub_ranges.map(&:id)).to eql([range1.id, range2.id])
    expect(res_range1.canvases.map(&:id)).to eql([canvases[0].id, canvases[1].id])
    expect(res_range1.sub_ranges.count).to eql(2)
    expect(res_range11.canvases.map(&:id)).to eql([canvases[0].id, canvases[1].id])
    expect(res_range12.canvases.count).to eql(0)
    expect(res_range2.canvases.map(&:id)).to eql([canvases[2].id, canvases[3].id, canvases[4].id])
    expect(res_range2.sub_ranges.count).to eql(0)    
  end
    
  it "adds ranges" do
    range2_json['ranges'] = ['jstree:newid1']
    ranges_json.push({
      '@id'=>'jstree:newid1', 
      '@type'=>'sc:Range', 
      'label'=>'New Range', 
      'canvases'=> [canvas_uris[4]]
    })
    
    expect(res_range2.canvases.map(&:id)).to eql([canvases[3].id, canvases[4].id])
    expect(res_range2.sub_ranges.count).to eql(1)
    new_range = res_range2.sub_ranges.first
    expect(new_range.id).not_to include('newid1')
    expect(new_range.title).to eql('New Range')
    expect(new_range.canvases.map(&:id)).to eql([canvases[4].id])
    expect(new_range.sub_ranges.count).to eql(0)
  end
  
  context "with canvas id mapping" do
    let(:actor_options) { { translate_canvases: true } }
    let(:manifest) { FactoryGirl.create(:iiifmanifest, ordered_members: canvases ) }
    let(:ranges_json){
      [
        {
          '@id'=>'jstree:range1', 
          '@type'=>'sc:Range', 
          'label'=>'Contents', 
          'viewingHint'=>'top',
          'canvases'=> ['http://example.com/1','http://example.com/2','http://example.com/3','http://example.com/4','http://example.com/5'],
          'ranges'=> ['jstree:range2', 'jstree:range3']
        },
        {
          '@id'=>'jstree:range2', 
          '@type'=>'sc:Range', 
          'label'=>'Chapter 1', 
          'canvases'=> ['http://example.com/1','http://example.com/2']
        },
        {
          '@id'=>'jstree:range3', 
          '@type'=>'sc:Range', 
          'label'=>'Chapter 2', 
          'canvases'=> ['http://example.com/3','http://example.com/4','http://example.com/5']
        },        
      ]
    }
    it "maps canvas ids" do
      expect(res_top_range).to be_present
      expect(res_top_range.canvases.map(&:id)).to eql([canvases[0].id,canvases[1].id,canvases[2].id,canvases[3].id,canvases[4].id])
      expect(res_top_range.sub_ranges.count).to eql(2)
      new_range1 = res_top_range.sub_ranges[0]
      new_range2 = res_top_range.sub_ranges[1]
      expect(new_range1.canvases.map(&:id)).to eql([canvases[0].id,canvases[1].id])
      expect(new_range1.sub_ranges).to be_empty
      expect(new_range1.title).to eql('Chapter 1')
      expect(new_range2.canvases.map(&:id)).to eql([canvases[2].id,canvases[3].id,canvases[4].id])
      expect(new_range2.sub_ranges).to be_empty
      expect(new_range2.title).to eql('Chapter 2')
    end
  end
  context "with old style iiif" do
    let(:actor_options) { { translate_canvases: true } }
    let(:manifest) { FactoryGirl.create(:iiifmanifest, ordered_members: canvases ) }
    let(:ranges_json){
      [
        {
          '@id'=>'jstree:range1', 
          '@type'=>'sc:Range', 
          'label'=>'Contents', 
          'viewingHint'=>'top',
          'canvases'=> ['http://example.com/1','http://example.com/2','http://example.com/3','http://example.com/4','http://example.com/5'],
        },
        {
          '@id'=>'jstree:range2', 
          '@type'=>'sc:Range', 
          'label'=>'Chapter 1', 
          'within'=>'jstree:range1',
          'canvases'=> ['http://example.com/1','http://example.com/2']
        },
        {
          '@id'=>'jstree:range3', 
          '@type'=>'sc:Range', 
          'label'=>'Chapter 2', 
          'within'=>'jstree:range1',
          'canvases'=> ['http://example.com/3','http://example.com/4','http://example.com/5']
        },        
      ]
    }
    it "adapts json" do
      expect(res_top_range).to be_present
      expect(res_top_range.canvases.map(&:id)).to eql([canvases[0].id,canvases[1].id,canvases[2].id,canvases[3].id,canvases[4].id])
      expect(res_top_range.sub_ranges.count).to eql(2)
      new_range1 = res_top_range.sub_ranges[0]
      new_range2 = res_top_range.sub_ranges[1]
      expect(new_range1.canvases.map(&:id)).to eql([canvases[0].id,canvases[1].id])
      expect(new_range1.sub_ranges).to be_empty
      expect(new_range1.title).to eql('Chapter 1')
      expect(new_range2.canvases.map(&:id)).to eql([canvases[2].id,canvases[3].id,canvases[4].id])
      expect(new_range2.sub_ranges).to be_empty
      expect(new_range2.title).to eql('Chapter 2')
    end
  end  
end