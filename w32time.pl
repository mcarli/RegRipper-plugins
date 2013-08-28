#------------------------------------------------------------------------------
# w32time
#   Get parameters of W32Time service
#
# Change history
#   20130828 - first version
#
# References
#   n/a
#
# Copyright
#   mc (c) 2013
#
#------------------------------------------------------------------------------

package w32time;
use strict;

my %config =
(
  hive          => "on",
  hasShortDescr => 1,
  hasDescr      => 1,
  hasRefs       => 1,
  osmask        => 31,
  version       => 20130828
);

sub getConfig     {return %config;}
sub getShortDescr {return "Get parameters of W32Time service";}
sub getDescr      {return "The W32Time keys contains all infos about system synchronization";}
sub getRefs       {return "n/a";}
sub getHive       {return $config{hive};}
sub getVersion    {return $config{version};}

my $VERSION = getVersion();

sub pluginmain{
  my $class = shift;
  my $hive = shift;
     ::logMsg('Launching w32time v'.$VERSION);
     ::rptMsg('w32time v'.$VERSION.' ('.getShortDescr().")");
  my $reg = Parse::Win32Registry->new($hive);
  my $root_key = $reg->get_root_key;
     
# Code for System file, getting CurrentControlSet
  my $current;
  my $ccs;
  my $key_path = 'Select';
  my $key;
  if ($key = $root_key->get_subkey($key_path)) {
    $current = $key->get_value("Current")->get_data();
    $ccs = "ControlSet00".$current;
  }
  else {
    ::logMsg("Could not find ".$key_path);
    return
  }

  enum_recursively ($root_key, $ccs."\\Services\\W32Time\\Parameters", 1,"");
}

sub hexify{
  my $data = shift;
  my $l='';
  my $r='';
  my $n=0;
  my $nd='';
  for (my $i=0; $i<length($data); $i++){
    my $c = substr($data, $i, 1);
    $l.=sprintf("%02X ",ord($c));
    if ($c=~ m/[ -~]/) {$r.=$c;}else{$r.='.';}
    $n++;
    if ($n>15){
      $nd.=sprintf("%-48s%s\n", $l,$r);
      $l='';$r='';$n=0;
    }
  }
  if ($n!=0){
    $nd.=sprintf("%-48s%s\n", $l,$r);
  }
  return $nd;
}

sub enum_recursively{
  my $root_key = shift;
  my $key_path = shift;
  my $rec_level = shift;
  return if ($rec_level>3);
  my $find = shift;$find = '.' if $find eq '';
  my $key;
  my $key_printed=0;
  my $sep = ' ' x 2;

  if ($key = $root_key->get_subkey($key_path)){

    $sep = ' ' x 4;
    my @vals = $key->get_list_of_values();
    my %ac_vals;
    foreach my $v (sort {lc($a) <=> lc($b)} @vals){
        my $vd = $v->get_data();
        my $vt = $v->get_type_as_string();
        if ($vt !~ /REG_(DWORD|SZ|EXPAND_SZ)/){
         $vd = hexify($vd);
        }
        $ac_vals{$v->get_name()}{'VT'} = $vt;
        $ac_vals{$v->get_name()}{'VD'} = $vd;
    }
    foreach my $a (sort {lc($a) <=> lc($b)} keys %ac_vals){
        my $ax = $a; $ax = '(Default)' if $a eq '';
        my $vt = $ac_vals{$a}{'VT'};
        my $vd = $ac_vals{$a}{'VD'};
        if (($a.$vd) ne ''&& ($ax.$a.$vd) =~/$find/is){
            if ($key_printed==0)
            {
              ::rptMsg("\n");
              ::rptMsg($sep.$key_path);
              ::rptMsg($sep.'LastWrite Time '.gmtime($key->get_timestamp())." (UTC)\n");
            $key_printed=1;
            }
            $sep = ' ' x 4;
            ::rptMsg($sep.$ax);
            $sep = ' ' x 6;
            ::rptMsg($sep.$vt);
            $sep = ' ' x 8;
            if ($vt !~ /REG_(DWORD|SZ|EXPAND_SZ)/)
            {
             $vd =~ s/[\n]+/\n$sep/sg;
            }
            ::rptMsg($sep.$vd);
        }
    }
    my @subkeys = $key->get_list_of_subkeys();
    if (scalar(@subkeys) > 0){
       foreach my $s (@subkeys){
         enum_recursively ($root_key , $key_path."\\".$s->get_name(), $rec_level + 1,$find);
       }
    }
  }
  else{
    ::rptMsg($sep.$key_path.' not found.');
  }
}

