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
        const $select = $(insertedItem).find('.js-select2-tags');

        // Disable blank option
        $select.find('option[value=""]').prop('disabled', true);

        // Initialize Select2
        $select.select2({
            tags: true,
            tokenSeparators: [','],
            width: '100%',
            theme: "bootstrap",
            placeholder: "Select or type",
            allowClear: true,
        });
        // Ensure disabled option stays disabled in Select2 (Select2 may clone options)
        $select.on('select2:opening select2:open', function() {
            $select.find('option[value=""]').prop('disabled', true);
        });
    }
});

$(document).on('cocoon:before-remove', function(e, item) {
    const $wrapper = $('#event_prices_wrapper');
    // If only one row is visible, prevent deletion
    if ($wrapper.find('.nested-fields:visible').length <= 1) {
        e.preventDefault();
        alert('You must have at least one price.');
        e.stopImmediatePropagation();
        return false;
    }
});
