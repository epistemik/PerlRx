package Process::PdfRepair;

#---------------------------------------------------------------
# NAME
#   PdfRepair.pl
#
# INPUTS
#   PDF file which may or may not be in need of repairs.
#
# OUTPUTS
#   The original PDF and if repairs were needed and successful a repaired
#   child with metadata.
#
# DESCRIPTION
#   PdfRepair.pl checks PDF files for repairable damage and does those repairs
#
#   PdfRepair.pl processes files that ValidateDataContent indentifies as
#   being PDF documents.  It looks for damage to vital top level PDF
#   structures such as the Xref table and root Catalog object.  It also
#   makes an attempt to check the integrity of the page tree.  It replaces
#   missing xref and Catalog objects and attempts repairs to the top of
#   damaged page trees.  Page tree repairs are partial and only effective
#   in making the document readable to some reader programs when the damage
#   to the original document was not too severe.  Page order information
#   will normally be lost along with the original page tree nodes it was
#   contained in.  A check for more severe damage will activate a more
#   complete rebuild that puts intact objects into a new PDF document template.
#
# IMPLEMENTATION LOGIC
#
#   PdfRepair.pl attempts to repair a document.  It effectively checks for
#   missing xref tables and catalog objects and replaces them if necessary.
#   It will go further and make an attempt to fix up a damaged page tree so
#   that the document is readable.  The success of page tree repair
#   attempts depends on what has survived and just how finicky the reader
#   used on the repaired document is.  It attempts to replace missing page
#   tree nodes with new ones with the same object number based on the
#   parent refs in 'orphans'.  The 'ca_extract' program in particular is
#   sensitive to inconsistencies in these values.  Some page order
#   information will be lost with each missing page tree node and the more,
#   and the lower down damage is to a page tree the less likely a repair
#   will succeed.  Metadata, information, and encryption objects are
#   ignored. A check for the page tree being entirely missing or for gaps
#   in the object list now does a complete rebuild using intact objects.
#   A later addition ("rebuildPdfTop()") to the repair code attempts to
#   repair documents more badly damaged code than the initial approach
#   could handle.  It will handle documents that the header has been
#   lost from.  Essentially the approach is to strip out all the intact
#   objects from a PDF document fragment and insert them into a simplified
#   but intact PDF document.
#
# ASSUMPTIONS
#
#   That the incoming document is PDF without severe damage at the page
#   and lower levels.  That is vital resources like fonts or images aren't
#   completely missing.
#
# LIMITATIONS
#
#   See assumptions.  Basically PdfRepair.pl does only the simplest of
#   checks on the sort of damage a PDF document has before checking for the
#   presence of the very top level document objects and replacing them if
#   necessary.  It does not repair or replace badly damaged or entirely
#   missing page trees, or any problems at the page or sub-page level.
#   That is if pages, or fonts or images or entire page tree branches are
#   missing nothing is done about it.  Actual data corruption is not
#   addressed either.  No report of the nature and extent of document
#   damage, or of the attempted repairs is made either embedded in the
#   repaired document or separately.
#
#   Error checking and handling is limited and straightforward.  If any of
#   a number standard problems occur (mainly obivous failure to be able to
#   repair or an inability to open a necessary file) the routine makes a
#   short standard report, and quits, leaving a short message in metadata
#   processing history usually.
#
#---------------------------------------------------------------

use warnings;

my $inputFile = shift;
my $content;

open(my $fh, '<', $inputFile);
{
	local $/;
	$content = <$fh>;
}
close($fh);

my $outRef = "";


# Check Pdf for repairs can do, if a damaged repairable doc then
# create a repaired child

my $repaired = chkPDFforRepair(\$content, \$outRef);

my $outputFile = shift;
unlink ($outputFile);

open OUTFILE, ">$outputFile";

# Pass to handler
handleItem($repaired, $outRef);

sub handleItem
{

    my ($data, $out) = @_;

    if ($data =~ /^No Need/)
    {
	print "Repairable damage not detected\n";
	close OUTFILE;	

	exit(0);
    }

    elsif ($data =~ /^Repaired OK/)
    {
	print "Repair succeeded\n";
	print OUTFILE "$out\n";
	close OUTFILE;
	
	exit(0);
	
    }

    elsif ($data =~ /^Damaged-Not Repaired/)
    {
	print "Damaged but repair not done\n";
	close OUTFILE;	

	exit(0);
    }

    else
    {
	print "Error attempting repair\n";
	close OUTFILE;	

	exit(0);
    }
}

#----------------------------------------------------------------------------
# NAME:         chkPDFforRepair
#
# DESCRIPTION:  check if can be repaired and if so, do so
#
# ARGS:         $dataRef, $outRef
#
# RETURN(S):    $retval
#-----------------------------------------------------------------------------
sub chkPDFforRepair
{
    my ($dataRef, $outRef) = @_;

    my $retVal = "Unknown Case";

    my $curTable = "";
    my $length   = 0;
    my $offset   = 0;
    my $bgnCur   = 0;

    $length = length $$dataRef;
	

    my $hasTrailer = 0;
    my $isNewHdr   = 0;
    my $objLook    = "";

    # Need at least some objects to work with
    if (not($$dataRef =~ /\d+ \d+ obj/)) {return ("Damaged-Not Repaired");}

    # And need those objects to have some extractable content too, if there
    # are document properties or metadata they count too and we'll try to
    # repair the document even if it consists of nothing but blank pages.
    my $contentFound = 0;
    if (
           ($$dataRef =~ /\/Author/)
        || ($$dataRef =~ /\/CreationDate/)
        || ($$dataRef =~ /\/Type\s*\/Metadata/)

        )
    {
        $contentFound = 1;
    }

    my $contentLength = 0;
    while ((not $contentFound) && ($$dataRef =~ /stream(.*?)endstream/gcs))
    {

        $contentLength += length($1);
        # 72 is magic number based on trial and error; short "hello.pdf"
        # with "hello world" content has about 80 bytes of content and
        # have examples of PDFs too damaged to be useful with 65 bytes
        # of stream content.
        if ($contentLength > 72) {$contentFound = 1;}

    }    # end while

    while ((not $contentFound) && ($$dataRef =~ /stream(.*)\z/gs))
    {

        $contentLength += length($1);
        if ($contentLength > 72) {$contentFound = 1;}
    }



    if (not $contentFound) {return ("Damaged-Not Repaired");}

    # Some readers will ignore the lack of header but usually it's required
    # This means xref likely needs fix up, but it's unclear how extensive other
    # damage will be so flag header has been replaced and let decision as to further
    # processing take place later.
    if (not($$dataRef =~ /\%PDF-(\d.\d)/))
    {

        $$dataRef = "\%PDF-1.4\n\%\xe2\xe3\xe4\xe5\n" . "\%Repaired_by_ICEPACK\n" . $$dataRef;
        $isNewHdr = 1;
    }

    # Check for severe damage to page tree here, or missing middle sections
    # in document, and do full rebuild if find them. Return from routine when
    # rebuild done.
    $objLook = lookObjs($dataRef);
    if ((not($$dataRef =~ /\/Type\s*\/Pages/)) || ($objLook =~ /has gaps/))
    {
        $retVal = rebuildPdfTop($outRef, $dataRef);
        return ($retVal);
    }

    # Will only reach here if damage wasn't found to be too bad above,
    # check for milder sorts of damage now and try a more elaborate but
    # information preserving repair of the page tree and Xref if it appears
    # needed.
    pos($$dataRef) = 0;
    if ((not($$dataRef =~ /[^\w](xref(.*?)%%EOF(.?)$)/s)) || $isNewHdr)
    {

        $curTable   = $1;
        $hasTrailer = 1;
        $retVal     = repairPdfTop($outRef, $dataRef);

    }    # end while finding trailers
    else
    {
        # We didn't find damage of the obvious sort or that
        # which we can repair
        return ("No Need");
    }

    return $retVal;

}    # chkPDFforRepair

#----------------------------------------------------------------------------
# NAME: repairPdfTop
#
# DESCRIPTION:Repairs top of PDF file.
#
# ARGS:      $outRef, $dataRef
#
# RETURN(S): string
#-----------------------------------------------------------------------------
sub repairPdfTop
{
    my ($outRef, $dataRef) = @_;

    my $catalogNum  = 0;
    my $catalogVer  = 0;
    my $pageRootNum = 0;
    my $numObjs     = 0;

    my %pageTreeObjNum  = ();
    my %refPageTreeUniq = ();
    my %parentNum       = ();

    my %objOffsets = ();
    my %objVers    = ();

    # excise any truncated xfer or obj at doc's end
    # do this before collect object info so don't pick
    # up any info on truncated object.
    pos($$dataRef) = 0;
    if (not($$dataRef =~ /[^\w]xref(.*?)%%EOF(.?)$/s))
    {

        $$dataRef =~ s/^((.*)(endobj)(.?))(.*?)$/$1/s;
    }

    pos($$dataRef) = 0;
    while ($$dataRef =~ m|((\d+) (\d+) (obj(.*?)endobj))|gs)
    {
        $numObjs++;
        my $haveFound = $1;
        my $objnum    = $2;
        my $objver    = $3;
        my $objBody   = $4;
        my $objdata   = $5;

        my $offset = pos $$dataRef;
        my $length = length $haveFound;
        my $bgnCur = $offset - $length;

        if (   (not exists $objOffsets{$objnum})
            || ($objver >= $objVers{$objnum}))
        {
            $objOffsets{$objnum} = $bgnCur;
            $objVers{$objnum}    = $objver;
        }

        if ($objBody =~ /\/Type\s*\/(\w+)/)
        {

            my $objType = $1;
            if (($objType =~ /Catalog/) && ($objver >= $catalogVer))
            {
                $catalogVer = $objver;
                $catalogNum = $objnum;

                if ($objBody =~ /\/Pages\s+(\d+)\s+\d+\s+R/)
                {

                    $pageRootNum = $1;

                }
            }
            elsif ($objType =~ /Pages/)
            {    #note the 's', is a node

                my $count = 1;
                if ($objdata =~ /\/Count\s+(\d+)/)
                {
                    $count = $1;
                }
                $pageTreeObjNum{$objnum} = $count;

                if ($objdata =~ /\/Kids\s*\[([^\]]+)\]/)
                {
                    my $kids = $1;

                    while ($kids =~ /(\d+)\s+(\d+)\s+R/g)
                    {
                        $refPageTreeUniq{$1} = 1;
                    }    # end while loop over kid references
                }    # end if have kids

                # keeping track of parents will let us see who's missing
                # important because various readers track this and complain
                # if who the kids say are their parents doesn't match what
                # objects are claiming to be their parents (like when I sub
                # in a 'foster' parent because the original seems to be gone)
                if ($objdata =~ /\/Parent\s+(\d+)\s+(\d+)\s+R/)
                {
                    $parentNum{$objnum} = $1;
                }
            }
            elsif ($objType =~ /^Page$/)
            {    # actual page and leaf of page tree

                $pageTreeObjNum{$objnum} = 1;

                # keeping track of parents will let us see who's missing
                if ($objdata =~ /\/Parent\s+(\d+)\s+(\d+)\s+R/)
                {
                    $parentNum{$objnum} = $1;
                }
            }
        }    # end check objBody for Type field
    }    # end while over objects

    if (not($$dataRef =~ /[\n\r]$/))
    {
        $$dataRef = $$dataRef . "\n";
    }

    # get length (offset for new xref) of clean ending doc data
    my $length = length $$dataRef;
    my $pgTree = "";

    # if we've  got more than one page tree object without a parent
    # in the page tree (its root) or the catalog object is missing
    # the page tree needs to be fixed.

    # HMK: corrected the 'if' statement below. 'scalar %hash' gives a string like "4/16", which is not numeric
    #if ((((scalar %refPageTreeUniq) + 1) < (scalar %pageTreeObjNum)) || ($catalogNum < 1)) {

    if ((((keys %refPageTreeUniq) + 1) < (keys %pageTreeObjNum)) || ($catalogNum < 1))
    {    # correct 'if' statement

        $pgTree = fixPageTree($catalogNum, $dataRef, \%refPageTreeUniq, \%pageTreeObjNum, \%parentNum, \%objOffsets);
        if ($pgTree)
        {

            # if rebuilt page tree catalog will be newly created highest numbered
            # object.
            my @objOffsetList = sort numerically keys %objOffsets;
            $catalogNum = $objOffsetList[$#objOffsetList];
            $catalogVer = 0;
        }
        else
        {
            # Report problem with fixing page tree
            Log("Problem creating page tree", 'warning');
        }
    }

    # in case changed
    $length = length $$dataRef;

    # make the new xref
    my $newXref = makeXref($length, $catalogNum, $catalogVer, \%objOffsets);

    if (not $newXref) {return "Damaged - repair attempt failed.";}

    # As fix up to offsets and references might be necessary can't write file
    # out until fully processed

    # Write out what we've salvaged from original (plus any page tree repairs)
    $$outRef = $$dataRef;

    # Write out our new constructed xref/trailer pair as final part of
    # new repaired version of pdf doc
    $$outRef .= $newXref;

    return "Repaired OK";
}    # repairPdfTop

#----------------------------------------------------------------------------
# NAME: fixPageTree
#
# DESCRIPTION:  Fixes the page tree.
#
# ARGS:         $catNum, $dataRef, $refsPgTreeRef, $objsPgTreeRef, $parentsRef
#               $offsetsRef
#
#-----------------------------------------------------------------------------
sub fixPageTree
{

    my ($catNum, $dataRef, $refsPgTreeRef, $objsPgTreeRef, $parentsRef, $offsetsRef) = @_;

    my $length = length $$dataRef;    # offset for first object in new page tree
                                      # may be altered by later patching

    # I calculate this highest obj num in several places but still
    # think this is cleaner and more modular than passing the results
    # of a single calculation around. Somewhat less efficient.
    my @objOffsetList = sort numerically keys %$offsetsRef;
    my $numHighestObj = $objOffsetList[$#objOffsetList];

    # find orphans
    my @orphans = ();
    my $curObj  = 0;
    foreach $curObj (keys %$objsPgTreeRef)
    {

        if (not exists $$refsPgTreeRef{$curObj})
        {
            push @orphans, $curObj;
        }
    }

    # start new page tree top construction
    my $tempPgTop = "";
    my $catStub   = " 0 obj\n<< \n/Type /Catalog \n/Pages ";

    # if only one orphan is root only need to build catalog root
    # object, otherwise need new page tree root foster parent too.
    my $numOrphans = scalar @orphans;

    if (($numOrphans > 0) && ($numOrphans < 2))
    {

        my $catNum = $numHighestObj + 1;
        $$offsetsRef{$catNum} = $length;

        $tempPgTop = $catNum . $catStub . $orphans[0] . " 0 R \n>> \nendobj\n";

        $$dataRef .= $tempPgTop;
    }
    else
    {

        my $pgTreeRootNum   = $numHighestObj + 1;
        my $catNum          = $numHighestObj + 2;    # object number of the root catalog
        my %missingParents  = ();                    # unique missing parent page tree nodes actually
        my @missParentsList = ();

        my $curOrphan = 0;
        foreach $curOrphan (@orphans)
        {

            $missingParents{$$parentsRef{$curOrphan}} = 1;

        }
        @missParentsList = keys %missingParents;

        if (@missParentsList > 0)
        {
            my $count        = 0;
            my $missedParent = 0;
            foreach $missedParent (@missParentsList)
            {
                $tempPgTop .= makePageTreeNode($missedParent, $pgTreeRootNum, \@orphans, $parentsRef, $objsPgTreeRef, \$count);
            }

            $tempPgTop .= makePageTreeRoot($pgTreeRootNum, \@missParentsList, $count);
        }

        # now do catalog too   ;
        $tempPgTop .= $catNum . $catStub . $pgTreeRootNum . " 0 R \n>> \nendobj\n";
        $$dataRef  .= $tempPgTop;
        updateOffsets($dataRef, $offsetsRef);
    }

    return $tempPgTop;

}    # fixPageTree

#----------------------------------------------------------------------------
# NAME: makePageTreeNode
#
# DESCRIPTION:  Creates a page tree node.
#
# ARGS:         $pgTreeNodeNum, $grandParent, $orphansRef, $parentsRef,
#               $descendCount, $countRef
#-----------------------------------------------------------------------------
sub makePageTreeNode
{
    my ($pgTreeNodeNum, $grandParent, $orphansRef, $parentsRef, $descendCount, $countRef) = @_;

    my $tempPgTreeNode = $pgTreeNodeNum . " 0 obj\n<< \n/Type /Pages \n/Kids [";

    my $numDescend = 0;
    my $curOrphan  = 0;
    foreach $curOrphan (@$orphansRef)
    {
        if ($$parentsRef{$curOrphan} == $pgTreeNodeNum)
        {
            $tempPgTreeNode .= $curOrphan . ' 0 R ';
            $numDescend += $$descendCount{$curOrphan};
            my $temp = $$descendCount{$curOrphan};
        }
    }

    $tempPgTreeNode .= "] \n/Count " . $numDescend;

    if ($grandParent)
    {
        $tempPgTreeNode .= " \n/Parent " . $grandParent . " 0 R";
    }

    $tempPgTreeNode .= " \n>> \nendobj\n";

    $$countRef += $numDescend;

    return $tempPgTreeNode;

}    # makePageTreeNode

#----------------------------------------------------------------------------
# NAME: makePageTreeRoot
#
# DESCRIPTION:  Creates a page tree root
#
# ARGS:         $pgTreeNodeNum, $orphansRef, $descendCount
#-----------------------------------------------------------------------------
sub makePageTreeRoot
{
    my ($pgTreeNodeNum, $orphansRef, $descendCount) = @_;

    my $tempPgTreeNode = $pgTreeNodeNum . " 0 obj\n<< \n/Type /Pages \n/Kids [";

    my $curOrphan = 0;
    foreach $curOrphan (@$orphansRef)
    {
        $tempPgTreeNode .= $curOrphan . ' 0 R ';
    }

    $tempPgTreeNode .= "] \n/Count " . $descendCount;

    $tempPgTreeNode .= " \n>> \nendobj\n";

    return $tempPgTreeNode;

}    # makePageTreeNode

#----------------------------------------------------------------------------
# NAME: updateOffsets
#
# DESCRIPTION:  get current byte offsets of objects in PDF document
#
# ARGS:         $dataRef, $offsetsRef
#-----------------------------------------------------------------------------
sub updateOffsets
{
    my ($dataRef, $offsetsRef) = @_;

    pos($$dataRef) = 0;
    while ($$dataRef =~ m|((\d+) (\d+) (obj(.*?)endobj))|gs)
    {
        my $haveFound = $1;
        my $objnum    = $2;

        my $offset = pos $$dataRef;
        my $length = length $haveFound;
        my $bgnCur = $offset - $length;

        my $temp = $$offsetsRef{$objnum};
        $temp = 0 if (not defined $temp);

        # assumption here is any conflicting new objects we create
        # will be appended at a higher offset value.
        if ($temp < $bgnCur)
        {
            $$offsetsRef{$objnum} = $bgnCur;
            # Not bothering with versions, single big replacement
            # xref table approach is not really sophisticated enough
            # to benefit I think.
        }
    }    # end while

}    # updateOffsets

# small sub-routine used for comparison in sorting.
sub numerically {$a <=> $b}

#----------------------------------------------------------------------------
# NAME: makeXref
#
# DESCRIPTION:  builds a new cross-reference table (Xref) for PDF document
#
# ARGS:        $length(offset to xref), $catalogNum, $catalogVer, $offsetsRef
#-----------------------------------------------------------------------------
sub makeXref
{
    my ($length, $catalogNum, $catalogVer, $offsetsRef) = @_;

    my $tempXref = "\x0dxref\n";
    $length++;    # adjust for extra carriage return above
    my $tempStr = "";
    my $objNum  = 0;

    my @objOffsetList = ();
    my $numHighestObj = 0;
    my $size          = 0;
    my $place         = 0;

    # sort offsets by object number because obj number is implicit
    # in order of Xref entries so it's important that be got right
    # Also important that place holders be put in for objects not
    # in sequence

    @objOffsetList = sort numerically keys %$offsetsRef;
    $numHighestObj = $objOffsetList[$#objOffsetList];
    $size          = $numHighestObj + 1;

    $tempXref .= "0 $size \r";
    $tempXref .= "0000000000 65535 f\r\n";

    $place = 1;
    while ($place <= $numHighestObj)
    {
        if (exists $$offsetsRef{$place})
        {
            $tempXref .= sprintf "%010d 00000 n\r\n", $$offsetsRef{$place};
        }
        else
        {
            $tempXref .= "0000000000 00001 f\r\n";
        }
        $place++;
    }

    $tempXref .= "trailer\r<<\r/Size $size\r/Root $catalogNum $catalogVer R \r>>\r";
    $tempXref .= "startxref\r$length\r";
    $tempXref .= "\%\%EOF\r";

    return $tempXref;
}    # makeXref

#----------------------------------------------------------------------------
# NAME: lookObjs
#
# DESCRIPTION:  Looks at objects present, and object references and compares
#
# ARGS:         $dataRef - reference to PDF document contents
#
# RETURN(S):    $results - string with results of examining objects
#-----------------------------------------------------------------------------
sub lookObjs
{
    my ($dataRef) = shift @_;

    my $rangeInit        = 0;
    my $numObjPresent    = 0;
    my $bgnObjRange      = 0;
    my $endObjRange      = 65000;
    my $numObjRefBelow   = 0;
    my $numObjRefAbove   = 0;
    my @objRefs          = ();
    my %objRefsUniq      = ();
    my @objPresent       = ();
    my %objPresentUniq   = ();
    my @objRefsInRange   = ();
    my @objRefsToPresent = ();
    my $results          = "";

    # Get objects present and their range
    pos($$dataRef) = 0;
    while ($$dataRef =~ m|((\d+) (\d+) (obj(.*?)endobj))|gs)
    {
        $numObjPresent++;
        my $haveFound = $1;
        my $objnum    = $2;
        my $objver    = $3;
        my $objBody   = $4;
        my $objdata   = $5;

        # Determine object present number range, initializing to first encountered
        # avoids having to hard code assumptions about the range
        if (not $rangeInit) {$bgnObjRange = $objnum; $endObjRange = $objnum; $rangeInit = 1;}

        if ($objnum < $bgnObjRange) {$bgnObjRange = $objnum;}
        if ($objnum > $endObjRange) {$endObjRange = $objnum;}

        # Add to list of present objects
        $objPresentUniq{$objnum} = 1;
    }

    # Get object references
    pos($$dataRef) = 0;
    while ($$dataRef =~ /\/\w+\s+(\d+)\s+(\d+)\s+R/g)
    {
        $objRefsUniq{$1} = 1;
    }

    # convert hashes used to avoid duplicates to lists
    @objPresent = keys %objPresentUniq;
    @objRefs    = keys %objRefsUniq;

    # Compare object ref and object present range information
    my $curObjRef = 0;
    foreach $curObjRef (@objRefs)
    {
        if    ($curObjRef < $bgnObjRange) {$numObjRefBelow++;}
        elsif ($curObjRef > $endObjRange) {$numObjRefAbove++;}
        else {push @objRefsInRange, $curObjRef;}
    }

    @objRefsToPresent = getIntersection(\@objPresent, \@objRefsInRange);

    # Fill our global data variables (at least ones not already set)
    my $numObjRefPresent = scalar @objRefsToPresent;
    my $numObjRefInRange = scalar @objRefsInRange;
    my $numObjRefTotal   = scalar @objRefs;

    # Fill out results string
    if ($numObjRefBelow)                     {$results .= "Likely decapitated, ";}
    if ($numObjRefAbove)                     {$results .= "Likely truncated, ";}
    if ($numObjRefTotal > $numObjRefPresent) {$results .= "Objects missing, ";}
    if ($numObjPresent < $numObjRefInRange)  {$results .= "Likely has gaps, ";}

    return ($results);
}    #  lookObjs

#----------------------------------------------------------------------------
# NAME: getIntersection
#
# DESCRIPTION:  Determine the union and intersection of the sets of
#               elements in two given arrays.
#
# ARGS:         $aRef -
#               $bRef -
#
# RETURN(S):    @isect -
#
# NOTES:
#      Helper code from the Perl cookbook
#      It returns an array with the intersection of the
#      values of two other arrays it got as parameters.
#-----------------------------------------------------------------------------
sub getIntersection
{
    my ($aRef, $bRef) = @_;

    my $e     = 0;
    my @union = ();
    my @isect = ();
    my %union = ();
    my %isect = ();

    foreach $e (@$aRef) {$union{$e} = 1}

    foreach $e (@$bRef)
    {
        if ($union{$e}) {$isect{$e} = 1}
        $union{$e} = 1;
    }
    @union = keys %union;
    @isect = keys %isect;

    return @isect;

}    #  getIntersection

#----------------------------------------------------------------------------
# NAME: getNotIn
#
# DESCRIPTION:  Return all the keys in first array not also in the second array
#
# ARGS:         $aRef -
#               $bRef -
#
# RETURN(S):    @diff
#
# NOTES:
#      Helper code from the Perl cookbook (chpt 4, section 7)
#-----------------------------------------------------------------------------
sub getNotIn
{
    my ($aRef, $bRef) = @_;

    my $e    = 0;
    my %seen = ();
    my @diff = ();

    foreach $e (@$bRef) {$seen{$e} = 1;}

    foreach $e (@$aRef)
    {
        unless ($seen{$e})
        {
            push(@diff, $e);
        }
    }

    return @diff;
}    #  getNotIn

#----------------------------------------------------------------------------
# NAME: rebuildPdfTop
#
# DESCRIPTION:  Rebuilds intact standard PDF around intact objects found in
#               original
#
# ARGS:         $outFilename, $dataRef
#-----------------------------------------------------------------------------
sub rebuildPdfTop
{
    my ($outRef, $dataRef) = @_;

    my $catalogNum  = 0;
    my $catalogVer  = 0;
    my $pageRootNum = 0;
    my $numObjs     = 0;
    my $maxObjID    = 0;

    my %parentNum = ();

    my %objOffsets = ();
    my %objVers    = ();
    my @pageObjs   = ();

    my $newPDFData = "";
    if (not($$dataRef =~ /\%PDF-(\d.\d)/))
    {
        $newPDFData = "\%PDF-1.4\n\%\xe2\xe3\xe4\xe5\n\%Repaired_by_DFb\n";
    }
    else
    {
        $newPDFData = "\%PDF-$1\n\%\xe2\xe3\xe4\xe5\n";
        $newPDFData .= "\%Repaired_by_DFc\n";
    }

    pos($$dataRef) = 0;
    while ($$dataRef =~ m|((\d+) (\d+) (obj(.*?)endobj))|gcs)
    {

        $numObjs++;
        my $curObj  = $1;
        my $objnum  = $2;
        my $objver  = $3;
        my $objBody = $4;
        my $objdata = $5;

        if ($objnum > $maxObjID) {$maxObjID = $objnum;}

        if ($objBody =~ /\/Type\s*\/(\w+)/)
        {

            my $objType = $1;
            if (($objType eq 'Catalog') || ($objType eq 'Pages'))
            {
                # Discard by ignoring all upper portion of page tree, catalog
                # root object and internal page tree nodes both
            }
            elsif ($objType eq 'Page')
            {    # actual page and leaf of page tree
                    # Save the pages will use them later but can't just add to
                    # document right away as must fix them up with their new
                    # parent first.
                push @pageObjs, $curObj;
            }
            else
            {

                # Other types of objects we add to our new simplified PDF document
                $newPDFData .= "\n $curObj";
            }

        }    # end check objBody for Type field
        elsif (not($objBody =~ /\/Linearized/))
        {
            # Other sorts of objects besides the Linearized one
            # we add to our new simplified PDF document
            $newPDFData .= "\n $curObj";
        }
    }    # end while over objects

    # pick up any final truncated objs; keep match position from while above
    while ($$dataRef =~ m|((\d+) (\d+) (obj(.*?)\z))|gcs)
    {

        $numObjs++;
        my $curObj  = $1;
        my $objnum  = $2;
        my $objver  = $3;
        my $objBody = $4;
        my $objdata = $5;

        if ($objnum > $maxObjID) {$maxObjID = $objnum;}

        $newPDFData .= "\n $curObj";

        # put missing end tags in
        if (($objdata =~ /[^d]stream/) && (not($objdata =~ /endstream/)))
        {
            $newPDFData .= "\nendstream";
        }

        if (not($objdata =~ /endobj/)) {$newPDFData .= "\nendobj";}

    }    # end while over last truncated obj

    # Will create first new object at max obj ID plus ten.
    # The "10" is arbritary these numbers just need to be unique.
    my $bgnNewObjs = $maxObjID + 10;
    if (@pageObjs < 1)
    {

        @pageObjs = makePages($dataRef, $bgnNewObjs);
        $bgnNewObjs += @pageObjs;
    }

    $pageRootNum = $bgnNewObjs + 10;
    $catalogNum  = $pageRootNum + 10;

    # Now add "Page" objects have stored to new PDF document fixing up
    # their Parent field values as do so, as well as building up the
    # "Kids" array for the "Pages" page tree root object
    my $curPage        = "";
    my $newParentField = "/Parent $pageRootNum 0 R ";
    my $kids           = "[ ";
    my $curKid         = "";
    my $kidCount       = 0;
    foreach (@pageObjs)
    {

        $curPage = $_;
        # fix up parent value
        $curPage =~ s/\/Parent\s*\d+ \d+\s*R/$newParentField/;

        $newPDFData .= "\n $curPage";

        # get page reference to add to Kids array
        $curPage =~ /(\d+ \d+)\s*obj/;
        $curKid = $1;

        $kids .= " $curKid R";
        $kidCount++;
    }

    $kids .= " ]";

    # Now create entirely new "Pages" root internal node to page tree and
    # a new Catalog document root object as the basis for our rebuilt
    # document.  They will have numbers outside (above) the old range,
    # and existing "Page" objects will need to be fixed up to point to
    # their new parent.

    my $newPageTreeRoot = "\n $pageRootNum 0 obj << ";
    $newPageTreeRoot .= "/Type /Pages ";
    $newPageTreeRoot .= "/Kids $kids ";
    $newPageTreeRoot .= "/Count $kidCount ";
    $newPageTreeRoot .= ">> endobj";

    my $newCatalog = "\n $catalogNum $catalogVer obj << ";
    $newCatalog .= "/Type /Catalog ";
    $newCatalog .= "/Pages $pageRootNum 0 R ";
    $newCatalog .= ">> endobj";

    $newPDFData .= "$newPageTreeRoot";
    $newPDFData .= "$newCatalog";

    # calculate offsets in new PDF doc
    updateOffsets(\$newPDFData, \%objOffsets);

    # get length of new document
    my $length = length $newPDFData;

    # make the new xref
    my $newXref = makeXref($length, $catalogNum, $catalogVer, \%objOffsets);

    if (not $newXref) {return "Damaged - repair attempt failed.";}

    # As fix up to offsets and references might be necessary can't write file
    # out until fully processed

    # Write out what we've salvaged from original (plus any page tree repairs)
    $$outRef = $newPDFData;

    # Write out our new constructed xref/trailer pair as final part of
    # new repaired version of pdf doc
    $$outRef .= $newXref;

    return "Repaired OK";
}    # rebuildPdfTop

#----------------------------------------------------------------------------
# NAME: makePages
#
# DESCRIPTION:  If document has no page tree leaf objects, but does have
#               data streams with potential content go through document and
#               create page leaf objects to contain that data.
#
# ARGS:        $dataRef, $bgnObjNum
#-----------------------------------------------------------------------------
sub makePages
{
    my ($dataRef, $bgnObjNum) = @_;

    my @pages = ();

    my %objPresentUniq = ();
    my %objRefsUniq    = ();
    my @objPresent     = ();
    my @objRefs        = ();

    my $oldPos = pos($$dataRef);
    pos($$dataRef) = 0;

    # start while loop that scans for each of the objects in a pdf doc
    while ($$dataRef =~ /(\d+)\s+(\d+)\s+(obj(.*?)endobj)/gs)
    {
        my $objNum  = $1;
        my $objVer  = $2;
        my $objBody = $3;
        my $objdata = $4;

        my $length = 0;
        if ($objBody =~ /\/Length\s(%d)/)
        {
            $length = $1;
        }

        my $objDict    = "";
        my $stream     = "";
        my $strmOffset = 0;
        my $strmLength = 0;
        if ($objBody =~ /stream[\x0d\x0a]{0,2}(.*?)[\x0d\x0a]{1,2}endstream/gs)
        {
            $stream     = $1;
            $strmLength = length $stream;

            $objBody =~ /<<(.*?)>>(.*?)[^d]?stream/s;
            $objDict = $1;

            $objPresentUniq{$objNum} = 1;
            # Any valid content stream will have a Length field with a positive
            # value, Also we're not interested in XObjects which are things like
            # images etc.
            if (($length > 0) && (not($objDict =~ /\/Type\s?\/XObject/))) {$objPresentUniq{$objNum} = 1;}

        }    # end if found stream
    }    # end while over objs

    # Get object references
    pos($$dataRef) = 0;
    while ($$dataRef =~ /\/\w+\s+(\d+)\s+(\d+)\s+R/g)
    {
        $objRefsUniq{$1} = 1;
    }

    # convert hashes used to avoid duplicates to lists
    @objPresent = keys %objPresentUniq;
    @objRefs    = keys %objRefsUniq;

    my @contents = getNotIn(\@objPresent, \@objRefs);

    my $parent     = $bgnObjNum + (@contents + 10);
    my $curPage    = $bgnObjNum;
    my $curPageObj = "";
    foreach (@contents)
    {

        $curPageObj = createPageObj($curPage, $parent, $_);
        push(@pages, $curPageObj);
        $curPage++;
    }

    return (@pages);
}    # makePages

#----------------------------------------------------------------------------
# NAME: createPageObj
#
# DESCRIPTION:  Creates a standard page leaf object with three parameters
#               given (object number of new page object, it's parent object
#               in the page tree, and the object num of a content stream it's
#               to contain)
#
# ARGS:         $objNum,  $parent, $content
#
# RETURN(S):    Newly created object in form of a string ($newPageObj)
#
# NOTES:
#-----------------------------------------------------------------------------
sub createPageObj
{

    my ($objNum, $parent, $content) = @_;

    my $newPageObj =
          "\n$objNum 0 obj\n<< /Type /Page \n"
        . "/Parent $parent 0 R \n"
        . "/MediaBox [ 0 0 612 792 ] \n"
        . "/Resources << >> \n"
        . "/Contents $content 0 R \n"
        . ">>\nendobj\n";

    return ($newPageObj);

}    # createPageObj

1;
