function should_i_commit
    set -l min_args 1
    set -l max_args 1
    if not argparse --min-args $min_args --max-args $max_args -- $argv
        set_color red
        printf "Usage: %s <threshold>\n" (status current-filename) >&2
        set_color normal
        return 1
    end

    set -l threshold $argv[1]
    # precondition: inside a git repo
    # nothing to do, if there are no changes
    if not git rev-parse --inside-work-tree >/dev/null 2>&1
        set_color red
        printf "Not inside a git repo\n" >&2
        set_color normal
        return 1
    end

    # example of output generated by `git diff --shortstat`:
    # "32 files changed, 835 insertions(+), 334 deletions(-)"
    git diff --shortstat \
        | string match --regex --all --groups-only '(\d+)' \
        | read --line --local files_changed insertions deletions

    # If no changes, `git diff --shortstat` returns nothing
    # and `string match` returns nothing
    # so we need to check if the variable is empty
    if test -z $files_changed
        set files_changed 0
    end
    if test -z $insertions
        set insertions 0
    end
    if test -z $deletions
        set deletions 0
    end

    # nothing to do, if there are no changes
    if test $files_changed -eq 0
        return 0
    end

    set -l number_of_lines_changed_in_repo_since_last_commit (math "$insertions + $deletions")

    if test $number_of_lines_changed_in_repo_since_last_commit -gt $threshold
        set -l git_color "#f44d27" # taken from git's logo
        set -l template "%s%s%s
in this repo %s%s%s at %s%s%s
%s%s%s lines have changed (insertions: %s%s%s, deletions: %s%s%s)
since your last commit. You SHOULD commit,
as this is above your set threshold of %s%s%s!
%s\n"

        set -l owner_and_repo (git config --local --get remote.origin.url | string match --regex --groups-only '([^/]+/[^/]+)\.git$') # extract the repo owner / repo name from the remote url e.g. kpbs5/git.fish
        set -l angry_emojis_sample_set 🤬 😠 😡 💀
        set -l angry_emojis_count (math "floor($number_of_lines_changed_in_repo_since_last_commit / $threshold)")
        
        set -l angry_emojis
        for i in (seq $angry_emojis_count)
			set -l random_index (random 1 (count $angry_emojis_sample_set))
			set -l random_emoji $angry_emojis_sample_set[$random_index]
			set --append angry_emojis $random_emoji
		end
        
		set -l angry_emojis (string join '' $angry_emojis)
        

        # set -l angry (string repeat --count (math "floor($number_of_lines_changed_in_repo_since_last_commit / $threshold)") 😠)
        set -l normal (set_color normal)
        set git_color (set_color $git_color)

        printf $template \
            $git_color "GIT ALERT!" $normal \
			$git_color $owner_and_repo $normal \
			$git_color $PWD $normal \
            $git_color $number_of_lines_changed_in_repo_since_last_commit $normal \
            (set_color green) $insertions $normal \
			(set_color red) $deletions $normal \
            $git_color $threshold $normal \
            $angry_emojis
    end
end
