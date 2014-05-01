package MT::Plugin::PSGIAppDisabler;
use strict;
use warnings;
use base qw( MT::Plugin );

my @ALWAYS_ENABLED_APPS  = qw( cms heartbeat );
my @ALWAYS_DISABLED_APPS = qw( search wizard );
my $USE_MT_CONFIG_CGI    = 0;
my @ALL_APPS;

my $plugin = __PACKAGE__->new(
    {   name    => 'PSGIAppDisabler',
        version => 0.03,

        author_name => 'masiuchi',
        author_link => 'https://github.com/masiuchi',
        plugin_link =>
            'https://github.com/masiuchi/mt-plugin-psgi-app-disabler',
        description => '<__trans phrase="Can disable PSGI applications.">',

        settings => MT::PluginSettings->new(
            [   [   'enabled_apps',
                    { Default => { upgrade => 1 }, Scope => 'system' }
                ]
            ],
        ),

        registry => {
            web_services => {
                PSGIAppDisabler => {
                    config_template => \&_config_tmpl,
                    save_config     => \&_save_config,
                },
            },
            config_settings => {
                EnabledApps  => { default => undef },
                DisabledApps => { default => undef },
            },
            callbacks => { post_init => \&_post_init },
        },
    }
);
MT->add_plugin($plugin);

sub _config_tmpl {
    my $app = MT->instance;
    return if $app->blog;

    my $enabled_apps = $plugin->get_config_value('enabled_apps');

    my @app_names = sort { $a cmp $b }
        grep { !_is_unmodifiable_app($_) } @ALL_APPS;

    my @apps;
    for my $name (@app_names) {
        my $script = MT->registry( 'applications', $name, 'script' );
        $script = $script->[0] if ref($script) eq 'ARRAY' && @$script;

        if ( !$script ) {
            $script = $name;
        }
        elsif ( $script =~ m/^\s*sub\s+/ ) {
            $script = eval $script;
        }
        elsif ( $script =~ m/^\$/ ) {
            $script = MT->handler_to_coderef($script);
            $script = $script->() if ref $script;
        }

        push @apps,
            {
            name   => $name,
            script => $script,
            $enabled_apps->{$name} ? ( enabled => 1 ) : (),
            };
    }

    my %param = (
        apps              => \@apps,
        use_mt_config_cgi => $USE_MT_CONFIG_CGI,
    );

    my $tmpl = $plugin->load_tmpl( 'web_service_config.tmpl', \%param );
    return $tmpl->build;
}

sub _save_config {
    my ( $cb, $app, $obj ) = @_;
    return if $app->blog;

    my @app_names = sort { $a cmp $b }
        grep { !_is_unmodifiable_app($_) } @ALL_APPS;

    my %enabled_apps;
    for (@app_names) {
        $enabled_apps{$_} = 1 if $app->param( 'psgi-' . $_ );
    }

    $plugin->set_config_value( 'enabled_apps', \%enabled_apps );

    $app->reboot;

    return 1;
}

sub _post_init {
    require MT::PSGI;
    my $application_list = \&MT::PSGI::application_list;

    no warnings;
    *MT::PSGI::application_list = sub {

        # Do original method.
        @ALL_APPS = $application_list->(@_);

        # EnabledApps
        my @enabled_apps = do {
            my $enabled_apps = MT->config->EnabledApps || '';
            grep {$_} split /\s*,\s*/, $enabled_apps;
        };
        if (@enabled_apps) {
            $USE_MT_CONFIG_CGI = 1;
            return @enabled_apps;
        }

        # DisabledApps
        my @disabled_apps = do {
            my $disabled_apps = MT->config->DisabledApps || '';
            grep {$_} split /\s*,\s*/, $disabled_apps;
        };
        if (@disabled_apps) {
            $USE_MT_CONFIG_CGI = 1;
            my @filtered_apps;
            for my $app (@ALL_APPS) {
                next if grep { $app eq $_ } @disabled_apps;
                push @filtered_apps, $app;
            }
            return @filtered_apps;
        }

        # Plugin Data
        return _get_enabled_apps_from_plugindata();
    };
}

sub _is_unmodifiable_app {
    my $name = shift;
    return unless $name;
    return ( grep { $_ eq $name }
            ( @ALWAYS_ENABLED_APPS, @ALWAYS_DISABLED_APPS ) ) ? 1 : 0;
}

sub _get_enabled_apps_from_plugindata {
    my $plugin_enabled_apps = $plugin->get_config_value('enabled_apps');
    my @maybe_enabled_apps
        = ( $plugin_enabled_apps && %$plugin_enabled_apps )
        ? ( keys(%$plugin_enabled_apps), @ALWAYS_ENABLED_APPS )
        : @ALWAYS_ENABLED_APPS;
    my @enabled_apps;
    for my $app (@maybe_enabled_apps) {
        if (   ( grep { $_ eq $app } @ALL_APPS )
            && ( grep { $_ ne $app } @ALWAYS_DISABLED_APPS ) )
        {
            push @enabled_apps, $app;
        }
    }
    return @enabled_apps;
}

1;
