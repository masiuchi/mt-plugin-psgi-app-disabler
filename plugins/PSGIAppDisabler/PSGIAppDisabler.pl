package MT::Plugin::PSGIAppDisabler;
use strict;
use warnings;
use base qw( MT::Plugin );

my $plugin = __PACKAGE__->new(
    {   name    => 'PSGIAppDisabler',
        version => 0.01,

        author_name => 'masiuchi',
        author_link => 'https://github.com/masiuchi',
        plugin_link =>
            'https://github.com/masiuchi/mt-plugin-psgi-app-disabler',
        description => <<'__DESC__',
<__trans phrase="Disable PSGI applications by DisableApps directive.">
<__trans phrase="(e.g. DisableApps comments,tb)">
__DESC__

        registry => {
            config_settings => { DisableApps => { default => undef } },
            callbacks       => { post_init   => \&_post_init },
        },
    }
);
MT->add_plugin($plugin);

sub _post_init {
    require MT::PSGI;
    my $application_list = \&MT::PSGI::application_list;

    no warnings;
    *MT::PSGI::application_list = sub {
        my @apps         = $application_list->(@_);
        my $disable_apps = MT->config->DisableApps;
        return @apps unless $disable_apps;

        my @disable_apps = split /\s*,\s*/, $disable_apps;
        my @enable_apps;
        for my $app (@apps) {
            next if grep { $app eq $_ } @disable_apps;
            push @enable_apps, $app;
        }
        return @enable_apps;
    };
}

1;
