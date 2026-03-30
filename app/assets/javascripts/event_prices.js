$(document).on('turbolinks:load', function() {
    // Only initialize Select2 on audience_type selects inside event_prices_wrapper
    $('#event_prices_wrapper .js-select2-tags').select2({
        tags: true,
        tokenSeparators: [','],
        width: '100%',
        theme: "bootstrap",
    });
});

// Handle newly added nested fields via Cocoon, scoped to event_prices_wrapper
$(document).on('cocoon:after-insert', function(e, insertedItem) {
    // Only initialize if the inserted item is inside event_prices_wrapper
    if ($(insertedItem).closest('#event_prices_wrapper').length > 0) {
        $(insertedItem).find('.js-select2-tags').select2({
            tags: true,
            tokenSeparators: [','],
            width: '100%',
            theme: "bootstrap"
        });
    }
});