import 'package:flutter/material.dart';

/// How dialog actions behave when they do not fit on one line.
///
/// Material stacks them in the order given, which puts Cancel on top and the
/// primary action beneath it: the button somebody opened the dialog to press
/// ends up second, under the one that abandons the job. Reversing the
/// direction leads with the action and leaves Cancel below it.
const VerticalDirection garageActionsOverflowDirection = VerticalDirection.up;

/// Stacked actions are centred rather than pinned to the right edge, where a
/// lone right-aligned Cancel under a full-width button reads as misplaced.
const OverflowBarAlignment garageActionsOverflowAlignment =
    OverflowBarAlignment.center;
