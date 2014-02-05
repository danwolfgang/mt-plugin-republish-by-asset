package RepublishByAsset::Plugin;

use strict;
use warnings;

# Called by a List Action.
sub republish_by_asset {
    my ($app) = @_;
    my $q     = $app->can('query') ? $app->query : $app->param;
    my $cur_blog_id = $app->blog ? $app->blog->id : '0';

    my @ids = $q->param('id');
    foreach my $id (@ids) {
        my $asset = $app->model('asset')->load( $id );

        # Look for any object that uses this asset ID. There could be many, so
        # we process them all in a loop.
        my $iter  = $app->model('objectasset')->load_iter({
            asset_id => $id,
        });
        while ( my $objasset = $iter->() ) {
            # Load the object referenced in the objectasset table -- most likely
            # either an `entry` or `page`.
            my $obj = $app->model( $objasset->object_ds )->load( $objasset->object_id )
                or next;

            # Republish the entry that was found.
            my $result = $app->rebuild_entry(
                Entry             => $obj,
                BuildDependencies => 1,
            );

            # Note the republish success/failure in the Activity Log.
            my ($status, $level);
            if ($result) {
                $level = $app->model('log')->INFO();
                $status = 'has republished';
            }
            else {
                $level = $app->model('log')->ERROR();
                $status = 'could not republish';
            }

            $app->log({
                level     => $level,
                class     => 'republish_by_asset',
                category  => 'publish',
                author_id => $app->user->id,
                blog_id   => $obj->blog_id,
                message   => 'Republish By Asset ' . $status . ' the '
                    . $obj->class . ' "' . $obj->title
                    . '" based on the association with the asset '
                    . $asset->label . ' '.$result,
            });
        }

    }

    # Go back to the Manage Assets screen.
    # $app->redirect( 
    #     $app->{cfg}->CGIPath . $app->{cfg}->AdminScript
    #     . '?__mode=list&_type=asset&blog_id=' . $cur_blog_id
    # );
    $app->call_return();
}

1;

__END__
