use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Opsview::Utils::NDOLogsImporter::XS',
    VERSION_FROM => 'lib/Opsview/Utils/NDOLogsImporter/XS.pm', # finds $VERSION
    PREREQ_PM => {}, # e.g., Module::Name => 1.1
    (
        $] >= 5.005
        ?            ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM => 'lib/Opsview/Utils/NDOLogsImporter/XS.pm'
            ,        # retrieve abstract from module
            AUTHOR => 'Alex J. G. Burzyński <a.burzynski@opsview.com>'
          )
        : ()
    ),
    LIBS   => [''],  # e.g., '-lm'
    DEFINE => '',    # e.g., '-DHAVE_SOMETHING'
    INC    => '-I.', # e.g., '-I. -I/usr/include/other'
                     # Un-comment this if you add C files to link with later:
      # OBJECT            => '$(O_FILES)', # link all the C files too
);
