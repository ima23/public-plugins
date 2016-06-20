=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Job::FileChameleon;

use strict;
use warnings;

use JSON qw(to_json);

use EnsEMBL::Web::Utils::FileHandler qw(file_put_contents);

use parent qw(EnsEMBL::Web::Job);

sub prepare_to_dispatch {
  ## @override
  my $self        = shift;
  
  my $rose_object     = $self->rose_object;
  my $job_data        = $rose_object->job_data;
  my $format          = $job_data->{format};
  my $chr_filter      = $job_data->{chr_filter};
  my $add_transcript  = $job_data->{add_transcript};
  my $remap_patch     = $job_data->{remap_patch};
  my $long_genes      = $job_data->{long_genes};
  my $config_content;

  my  $include  = [];
  
  if($long_genes) {
  # this is taken from examples/gff3_filter_large.conf on faang github repo
  # if this changes too often, get Matt Laird to move the fixed parts into a file on github (only length is editable)
  $config_content = {  
      "input_filter" => { "_pre" => "max_length", "_post" => "metoo_delete"},
      "output_filter" => { "_metadata" => "forward_ref" },
      "mapping" => {
        "max_length" => {
          "_callback" => "run",
          "_module" => "Bio::FormatTranscriber::Callback::MaxLength",
          "_init" => {"length" => $long_genes },
          "_parameters" => {"record" => "{{record}}" },
          "_filter" => 1
        },
        "forward_ref" => {
          "_callback" => "run",
          "_module" => "Bio::FormatTranscriber::Callback::EndReference",
          "_parameters" => {"record" => "{{record}}", "last_written" => "{{last_written}}"},
          "_filter" => 1
        },
        "metoo_delete" => {
          "_callback" => "run",
          "_module" => "Bio::FormatTranscriber::Callback::MeTooDelete",
          "_parameters" => {"record" => "{{record}}", "last_record" => "{{last_record}}"},
          "_filter" => 1
        }
      }
    }
  }

  if($chr_filter) {
    $config_content->{input_filter}->{seqname} = "chromosome|".lc($job_data->{species})."_".$chr_filter;
    push($include,"file:///localsw/FileChameleon/examples/chromosome.conf");
  }
  
  push($include,"file:///localsw/FileChameleon/examples/transcript_id.conf") if($add_transcript);
  push($include,"file:///localsw/FileChameleon/examples/remap.conf") if($remap_patch);  

  $config_content->{include} = $include;

  file_put_contents($rose_object->job_dir."/configuration.conf", to_json($config_content));

  return {
    'work_dir'      => $rose_object->job_dir,
    'output_file'   => "FileChameleon_output.$format.gz", #need to change the output file name to be the same as inputfile name with _converted
    'input_file'    => $job_data->{'file_url'},
    'just_download' => $job_data->{'just_download'},
    'format'        => $format,
    'config'        => "configuration.conf",
    'code_root'     => $self->hub->species_defs->ENSEMBL_HIVE_HOSTS_CODE_LOCATION
  };
}

# storing the files in /nfs/ensembl_download which can be accessed via download.ensembl.org
sub different_tmp {
  my $tmp_dir     = $SiteDefs::ENSEMBL_TMP_DIR_TOOLS;
  $tmp_dir        =~ s/ensembl_tmp/ensembl_download/i;

  return $tmp_dir;
}

1;
