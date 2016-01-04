function fisher_uninstall -d "Disable / Uninstall Plugins"
    set -l option
    set -l items
    set -l error /dev/stderr

    getopts $argv | while read -l 1 2
        switch "$1"
            case _
                set items $items $2

            case a all
                set option $option all

            case f force
                set option $option force

            case q quiet
                set error /dev/null

            case help h
                printf "usage: fisher uninstall [<name or url> ...] [--force] [--quiet] [--help]\n\n"

                printf "    -f --force  Delete copy from cache \n"
                printf "    -q --quiet  Enable quiet mode      \n"
                printf "     -h --help  Show usage help        \n"
                return

            case \*
                printf "fisher: '%s' is not a valid option\n" $1 >& 2
                fisher_uninstall --help >& 2
                return 1
        end
    end

    set -l count 0
    set -l duration (date +%s)
    set -l total (count $items)

    if set -q items[1]
        printf "%s\n" $items
    else
        fisher --file=-

    end | fisher --validate | fisher --translate | while read -l path

        if not test -d "$path"
            printf "fisher: '%s' not found\n" $path > $error
            continue
        end

        set -l name (basename $path)

        printf "Uninstalling " > $error

        switch $total
            case 0 1
                printf ">> %s\n" $name > $error

            case \*
                printf "(%s of %s) >> %s\n" (math 1 + $count) $total $name > $error
        end

        set count (math $count + 1)

        for file in $path/{*,functions{/*,/**/*}}.fish
            set -l base (basename $file)

            switch $base
                case {$name,fish_{,right_}prompt}.fish
                    functions -e (basename $base .fish)

                    if test "$base" = fish_prompt.fish
                        source $__fish_datadir/functions/fish_prompt.fish ^ /dev/null
                    end

                case {init,before.init,uninstall}.fish
                    set base $name.(basename $base .fish).config.fish
            end

            rm -f $file $fisher_config/{functions,conf.d}/$base
        end

        for file in $path/completions/*.fish
            rm -f $fisher_config/completions/(basename $file)
        end

        for n in (seq 9)
            if test -d $path/man/man$n
                for file in $path/man/man$n/*.$n
                    rm -f $fisher_config/man/man$n/(basename $file)
                end
            end
        end

        git -C $path ls-remote --get-url ^ /dev/null | fisher --validate | read -l url

        switch force
            case $option
                rm -rf $path
        end

        set -l file $fisher_config/fishfile

        if not fisher --file=$file | grep -Eq "^$name\$|^$url\$"
            continue
        end

        set -l tmp (mktemp -t fisher.XXX)

        if not sed -E '/^ *'(printf "%s|%s" $name $url | sed 's|/|\\\/|g'
        )'([ #].*)*$/d' < $file > $tmp
            rm -f $tmp
            printf "fisher: can't delete '%s' from %s\n" $name $file > $error
            return 1
        end

        mv -f $tmp $file
    end

    printf "%d plugin/s uninstalled (%0.fs)\n" $count (math (date +%s) - $duration) > $error

    test $count -gt 0
end
