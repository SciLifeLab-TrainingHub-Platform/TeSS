var CoursesForm = {
    init: function () {
        var $form = $('#course_form');
        if (!$form.length) return;

        CoursesForm.initAuthors();
        CoursesForm.initContributors();
        CoursesForm.bindSubmit($form);
    },

    initAuthors: function () {
        var $wrapper = $('#authors-wrapper');
        if (!$wrapper.length) return;

        var authorCount = $wrapper.find('.author-fields').length;

        $('#add-author').off('click.coursesFormAuthors').on('click.coursesFormAuthors', function () {
            authorCount++;
            var $clone = $wrapper.find('.author-fields').first().clone();

            $clone.find('input').val('');

            $clone.find('input').each(function () {
                var $input = $(this);
                var inputId = $input.attr('id');
                if (!inputId) return;

                var baseId = inputId.replace(/\d+$/, '');
                $input.attr('id', baseId + authorCount);
            });

            $clone.find('label').each(function () {
                var $label = $(this);
                var labelFor = $label.attr('for');
                if (!labelFor) return;

                var baseFor = labelFor.replace(/\d+$/, '');
                $label.attr('for', baseFor + authorCount);
            });

            $wrapper.append($clone);
        });

        $wrapper.off('click.coursesFormAuthors', '.remove-author').on('click.coursesFormAuthors', '.remove-author', function () {
            if ($wrapper.find('.author-fields').length > 1) {
                $(this).closest('.author-fields').remove();
            } else {
                alert('At least one author is required.');
            }
        });
    },

    initContributors: function () {
        var $wrapper = $('#contributors-wrapper');
        if (!$wrapper.length) return;

        var contributorCount = $wrapper.find('.contributor-fields').length;

        $('#add-contributor').off('click.coursesFormContributors').on('click.coursesFormContributors', function () {
            contributorCount++;
            var $clone = $wrapper.find('.contributor-fields').first().clone();

            $clone.find('input').val('');

            $clone.find('input').each(function () {
                var $input = $(this);
                var inputId = $input.attr('id');
                if (!inputId) return;

                var baseId = inputId.replace(/\d+$/, '');
                $input.attr('id', baseId + contributorCount);
            });

            $clone.find('label').each(function () {
                var $label = $(this);
                var labelFor = $label.attr('for');
                if (!labelFor) return;

                var baseFor = labelFor.replace(/\d+$/, '');
                $label.attr('for', baseFor + contributorCount);
            });

            $wrapper.append($clone);
        });

        $wrapper.off('click.coursesFormContributors', '.remove-contributor').on('click.coursesFormContributors', '.remove-contributor', function () {
            if ($wrapper.find('.contributor-fields').length > 1) {
                $(this).closest('.contributor-fields').remove();
            } else {
                alert('At least one contributor is required.');
            }
        });
    },

    bindSubmit: function ($form) {
        $form.off('submit.coursesFormAuthorsContributors').on('submit.coursesFormAuthorsContributors', function () {
            CoursesForm.serializeAuthors();
            CoursesForm.serializeContributors();
        });
    },

    serializeAuthors: function () {
        var $wrapper = $('#authors-wrapper');
        var $target = $('#course_authors');
        if (!$wrapper.length || !$target.length) return;

        var authors = [];
        $wrapper.find('.author-fields').each(function () {
            var $fields = $(this);
            var name = ($fields.find('[name="author_name[]"]').val() || '').trim();
            var affiliation = ($fields.find('[name="author_affiliation[]"]').val() || '').trim();
            var orcid = ($fields.find('[name="author_orcid[]"]').val() || '').trim();
            var email = ($fields.find('[name="author_email[]"]').val() || '').trim();

            if (name || affiliation || orcid || email) {
                authors.push({ name: name, affiliation: affiliation, orcid: orcid, email: email });
            }
        });

        $target.val(authors.length ? JSON.stringify(authors) : '');
    },

    serializeContributors: function () {
        var $wrapper = $('#contributors-wrapper');
        var $target = $('#course_contributors');
        if (!$wrapper.length || !$target.length) return;

        var contributors = [];
        $wrapper.find('.contributor-fields').each(function () {
            var $fields = $(this);
            var name = ($fields.find('[name="contributor_name[]"]').val() || '').trim();
            var affiliation = ($fields.find('[name="contributor_affiliation[]"]').val() || '').trim();
            var orcid = ($fields.find('[name="contributor_orcid[]"]').val() || '').trim();

            if (name || affiliation || orcid) {
                contributors.push({ name: name, affiliation: affiliation, orcid: orcid });
            }
        });

        $target.val(contributors.length ? JSON.stringify(contributors) : '');
    }
};

document.addEventListener("turbolinks:load", function () {
    CoursesForm.init();
});

