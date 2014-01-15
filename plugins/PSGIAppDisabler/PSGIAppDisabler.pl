package MT::Plugin::PSGIAppDisabler;
use strict;
use warnings;
use base qw( MT::Plugin );

my $plugin = __PACKAGE__->new(
    {   name    => 'PSGIAppDisabler',
        version => 0.02,

        author_name => 'masiuchi',
        author_link => 'https://github.com/masiuchi',
        plugin_link =>
            'https://github.com/masiuchi/mt-plugin-psgi-app-disabler',
        description => <<'__DESC__',
<__trans phrase="Disable PSGI applications by DisableApps directive.">
<__trans phrase="(e.g. EnableApps cms / DisableApps comments,tb)">
__DESC__

        registry => {
            config_settings => {
                EnableApps  => { default => undef },
                DisableApps => { default => undef },
            },
            callbacks => { post_init => \&_post_init },
        },
    }
);
MT->add_plugin($plugin);

sub _post_init {
    require MT::PSGI;
    my $application_list = \&MT::PSGI::application_list;

    no warnings;
    *MT::PSGI::application_list = sub {

        # Do origiinal method.
        my @raw_apps = $application_list->(@_);

        # EnableApps
        my @enable_apps = do {
            my $enable_apps = MT->config->EnableApps || '';
            grep {$_} split /\s*,\s*/, $enable_apps;
        };
        return @enable_apps if @enable_apps;

        # DisableApps
        my @disable_apps = do {
            my $disable_apps = MT->config->DisableApps || '';
            grep {$_} split /\s*,\s*/, $disable_apps;
        };
        return @raw_apps
            unless @disable_apps;    # Return raw apps if no DisableApps.

        my @filtered_apps;
        for my $app (@raw_apps) {
            next if grep { $app eq $_ } @disable_apps;
            push @filtered_apps, $app;
        }
        return @filtered_apps;
    };
}

1;
