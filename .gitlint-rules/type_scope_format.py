import re

from gitlint.rules import CommitRule, RuleViolation

types = [
    "feat",
    "fix",
    "chore",
    "docs",
    "refactor",
    "perf",
    "test",
    "ci",
    "build",
    "style",
    "init",
]

scopes = [
    "core",
    "catalogue",
    "finder",
    "tooling",
    "docs",
    "repo",
    "ci",
]

emoji_map = {
    "feat": "\u2728",
    "fix": "\U0001f41b",
    "chore": "\U0001f9f9",
    "docs": "\U0001f4dd",
    "refactor": "\u267b\ufe0f",
    "perf": "\u26a1",
    "test": "\u2705",
    "ci": "\U0001f477",
    "build": "\U0001f4e6",
    "style": "\U0001f3a8",
    "init": "\U0001f389",
}

vague_words = [
    "stuff",
    "wip",
    "misc",
    "things",
    "fix",
    "update",
    "changes",
    "tweak",
]

min_description_length = 10

scope_restatement_buffer = 20

issue_trigger_words = [
    "issue",
    "closes",
    "fixes",
    "resolves",
    "refs",
    "references",
    "relates",
]

_TITLE_PATTERN = re.compile(
    r"^(?P<type>{types})\((?P<scope>{scopes})\): (?P<emoji>{emojis}) (?P<description>.+?)(?: #(?P<issue>\d+))?$".format(
        types="|".join(re.escape(t) for t in types),
        scopes="|".join(re.escape(s) for s in scopes),
        emojis="|".join(re.escape(e) for e in emoji_map.values()),
    )
)

_WORD_PATTERN = re.compile(r"[a-z0-9']+")


class TypeScopeFormat(CommitRule):
    name = "type-scope-format"
    id = "UC1"

    def validate(self, commit):
        violations = []
        title = commit.message.title

        match = _TITLE_PATTERN.match(title)
        if not match:
            violations.append(
                RuleViolation(
                    self.id,
                    "Title must match 'type(scope): emoji description [#N]' using an "
                    "allowed type, an allowed scope, and the emoji required for that "
                    "type. Got: {0!r}".format(title),
                )
            )
            return violations

        commit_type = match.group("type")
        scope = match.group("scope")
        emoji = match.group("emoji")
        description = match.group("description")
        issue_number = match.group("issue")

        if emoji_map.get(commit_type) != emoji:
            violations.append(
                RuleViolation(
                    self.id,
                    "Emoji {0!r} does not match the required emoji {1!r} for type "
                    "'{2}'".format(emoji, emoji_map.get(commit_type), commit_type),
                )
            )

        if len(description) < min_description_length:
            violations.append(
                RuleViolation(
                    self.id,
                    "Description must be at least {0} characters long (got "
                    "{1})".format(min_description_length, len(description)),
                )
            )

        first_word = _WORD_PATTERN.match(description.lower())
        first_word = first_word.group(0) if first_word else ""
        if first_word in vague_words:
            violations.append(
                RuleViolation(
                    self.id,
                    "Description must not start with the vague word "
                    "'{0}'".format(first_word),
                )
            )

        if description[:1] and description[:1] != description[:1].lower():
            violations.append(
                RuleViolation(self.id, "Description must start with a lowercase letter")
            )

        normalised_description = description.lower()
        normalised_scope = scope.lower()
        scope_token_pattern = re.compile(
            r"\b{0}\b".format(re.escape(normalised_scope))
        )
        restates_scope = scope_token_pattern.search(normalised_description) is not None
        too_short_for_scope = len(normalised_description) < len(
            normalised_scope
        ) + scope_restatement_buffer
        if restates_scope and too_short_for_scope:
            violations.append(
                RuleViolation(
                    self.id,
                    "Description just restates the scope '{0}' without adding "
                    "detail".format(scope),
                )
            )

        body_text = "\n".join(commit.message.body)
        message_text = "{0}\n{1}".format(title, body_text).lower()
        mentions_issue_trigger = any(
            re.search(r"\b{0}\b".format(re.escape(word)), message_text)
            for word in issue_trigger_words
        )
        if mentions_issue_trigger and issue_number is None:
            violations.append(
                RuleViolation(
                    self.id,
                    "Message mentions an issue-related word but is missing a "
                    "trailing '#N' issue reference",
                )
            )

        return violations
