unit ged55utils;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdActns, Menus, ToolWin, ExtCtrls, StrUtils;

procedure ParseGedcom();
function GetLevel(const Line: string): integer;
function GetTag(const Line: string): string;
function GetRest(const Line: string): string;
procedure ProcessINDIRecord(var I: integer);
procedure ProcessFAMRecord(var I: integer);
procedure ProcessNOTERecord(var I: integer; const RecordID: string);
procedure ProcessSOURRecord(var I: integer);
procedure ProcessCitation(var I: integer);
procedure ProcessHeader(var I: integer);

var
  Line: string;   // gedcom line
  Lvl: integer;   // gedcom level
  Tag: string;    // gedcom tag (ie. INDI, FAMI, SOUR)
  Rest: string;   // the rest of the line after level and tag
  Quote: char;    // quote character for text fields
  Delim: string;  // delimiter character for text fielsds

const
  BaseLvl = 0;    // base level for all records in gedcom

implementation

uses
  Main, Prefs, DB;

{ ---------------------------------------------------------------------------- }

procedure ParseGedcom();
var
  I: integer; //used for looping
  StartCount, StopCount, Freq: int64; //used to calculate elapsed time

begin
  try
  { Update Status Log }
  UpdateStatusLog('Opening file: ' + GedcomFileName + '...');
  UpdateStatusLog('Loading file into memory...');
  Screen.Cursor := crHourglass;

  GedcomLines.Clear;
  GedcomLines.LoadFromFile(GedcomFileName);

  { Set Status Bar Panels }
  UpdateStatusBar(0, ExtractFileName(GedcomFileName));
  UpdateStatusBar(1, 'Status: Processing gedcom file');
  UpdateStatusLog('Processing file...');

  { Initialize Variables }
  I := 0;
  DefaultArrayInc := 1000; // sets arrays initial size and growth increments
  FactNum := 1;
  QueryPerformanceCounter(StartCount); // Get start time
  { Initialize Individual array and index variables }
  IndevIndex := 0;
  Finalize(IndivArray); // in case of data reload
  setlength(IndivArray, DefaultArrayInc, 7);
  { Initialize Fact array and index variables }
  FactIndex := 0;
  Finalize(FactArray); // in case of data reload
  setlength(FactArray, DefaultArrayInc, 5);
  { Initialize Relation array and index variables }
  RelatIndex := 0;
  Finalize(RelatArray); // in case of data reload
  setlength(RelatArray, DefaultArrayInc, 2);
  { Initialize Family array and index variables }
  FamIndex := 0;
  Finalize(FamArray); // in case of data reload
  setlength(FamArray, DefaultArrayInc, 6);
  { Initialize Note array and index variables }
  NoteIndex := 0;
  Finalize(NoteArray); // in case of data reload
  setlength(NoteArray, DefaultArrayInc, 2);
  { Initialize Source array and index variables }
  SourceIndex := 0;
  Finalize(SourceArray); // in case of data reload
  setlength(SourceArray, DefaultArrayInc, 3);
  { Initialize Citation array and index variables }
  CitationIndex := 0;
  Finalize(CitationArray); // in case of data reload
  setlength(CitationArray, DefaultArrayInc, 3);
  { Initialize Child array and index variables }
  ChildIndex := 0;
  Finalize(ChildArray); // in case of data reload
  setlength(ChildArray, DefaultArrayInc, 2);

  // Processing
  frmMain.GaugeSetup(True, 0, pred(GedcomLines.Count));
  frmMain.btnAbort.Visible := True;
  while I < pred(GedcomLines.Count) do begin
    Application.ProcessMessages;

    { Handle abort button }
    if AbortProc = True then begin
      exit;
    end;

    frmMain.GaugeProgress(I);
    Line := gedcomlines.strings[I];
    Lvl := GetLevel(Line);
    Tag := GetTag(Line);
    Rest := GetRest(Line);

    { Detect New Record }
    if (Lvl = BaseLvl) then begin
      if Rest = 'INDI' then ProcessINDIRecord(I)
      else if Rest = 'FAM'  then ProcessFAMRecord(I)
      else if Rest = 'SOUR' then ProcessSOURRecord(I)
      else if Rest = 'NOTE' then ProcessNOTERecord(I, '0')
      else if Tag  = 'HEAD' then ProcessHeader(I)
      else if Tag  = 'TRLR' then break;
    end;
    inc(I);
  end;

  finally
    { Handle aborted processing }
    if AbortProc = True then begin
      AbortProc := False;
      UpdateStatusLog('Process aborted.');
    end
    { Handle successful processing }
    else begin
      QueryPerformanceCounter(StopCount); //Get end time
      QueryPerformanceFrequency(Freq);

      { Trim empty rows from arrays }
      setlength(IndivArray, IndevIndex, 7);
      setlength(FactArray, FactIndex, 5);
      setlength(RelatArray, RelatIndex, 2);
      setlength(FamArray, FamIndex, 6);
      setlength(NoteArray, NoteIndex, 2);
      setlength(SourceArray, SourceIndex, 3);
      setlength(CitationArray, CitationIndex, 3);
      setlength(ChildArray, ChildIndex, 2);

      UpdateStatusLog('Processing Complete.');
      UpdateStatusLog('Lines Processed: ' + inttostr(GedcomLines.Count));
      UpdateStatusLog('Run Time: ' + format('%6.1n ms', [(StopCount - StartCount) * 1000 /
        Freq]));
      UpdateStatusLog('');

      { Enable the save button }
      SavingEnabled(True);

      { If SaveAfterProc is True then Save Data immediately }
      if SaveDFAfterProc = True then
        frmMain.FileSave1Execute(frmMain);

      if CalcStats then CalculateStats;
    end;

    { Cleanup after processing }
    frmMain.btnAbort.Visible := False;
    frmMain.GaugeSetup(False); { hide the progress gauge }
    UpdateStatusBar(1, 'Status:'); { Clear the StatusBar }
    Screen.Cursor := crDefault; { Restore default cursor }
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Returns the Level Number of the Gedcom line }
function GetLevel(const Line: string): integer;
begin
  Result := strtoint(copy(Line, 1, pred(pos(' ', Line))));
end;


{ ---------------------------------------------------------------------------- }
{ Returns the Tag (value) of the Gedcom Line }
function GetTag(const Line: string): string;
var
  TempStr: string;
  Start: integer;
  Count: integer;
begin
  TempStr := Line + ' '; // add whitespace in case of short line
  Start := succ(pos(' ', TempStr));
  Count := posex(' ', TempStr, Start) - Start;
  Result := copy(TempStr, Start, Count);
end;

{ ---------------------------------------------------------------------------- }
{ Returns the rest of the Gedcom line (if any) }
function GetRest(const Line: string): string;
var
  TempStr: string;
begin
  TempStr := Line;
  delete(TempStr, 1, pos(' ', TempStr)); // strip out the level record
  if pos(' ', TempStr) > 0 then begin
    Result := copy(TempStr, succ(pos(' ', TempStr)), pred(maxint));
  end
  else
    Result := '';
end;

{ ---------------------------------------------------------------------------- }
{ Process the INDI record and store the results }
procedure ProcessINDIRecord(var I: integer);
type
  { Defines types of events that will be processed }
  TIndivEventType =
    (evtBirth, evtChristening, evtDeath, evtBurial, evtCremation, evtBaptism, evtBarMitzvah,
    evtBasMitzvah, evtBlessing, evtBaptismLDS, evtAChristening, evtConfirmation, evtWill,
    evtProbate, evtOccupation, evtSSN, evtCensus, evtEmigration, evtImmigration, evtResidence,
    evtFirstCommunion, evtOrdinance, evtNaturalization, evtGraduation, evtRetirement,
    evtAdoption, evtCaste, evtDescription, evtEducation, evtIDNumber, evtNationality,
    evtNumOfChildren, evtNumOfMarriages, evtPossessions, evtReligion, evtTitle, evtOther);
  { Defines types of information to gather about an individual }
  TIndivInfo =
    (indName, indAlias, indTitle, indSex, indFamily, indNote);
  { Stores data about an individual }
  TIndivRecord = record
    IndKey: string;
    Title: string;
    Surname: string;
    GivenName: string;
    FullName: string;
    Aka: string;
    Sex: string;
    NoteKey: string;
    FamKey: string;
  end;

const
  { Defines gedcom tags that correspond to event types }
  EventType: array[TIndivEventType] of string =
  ('BIRT', 'CHR', 'DEAT', 'BURI', 'CREM', 'BAPM', 'BARM', 'BASM', 'BLES', 'BAPL', 'CHRA',
    'CONF', 'WILL', 'PROB', 'OCCU', 'SSN', 'CENS', 'EMIG', 'IMMI', 'RESI', 'FCOM', 'ORDI',
    'NATU', 'GRAD', 'RETI', 'ADOP', 'CAST', 'DSCR', 'EDUC', 'IDNO', 'NATI', 'NCHI', 'NMR',
    'PROP', 'RELI', 'TITL', 'EVEN');
  { Defines text descriptions that correspond to gedcom tags}
  EventDescrip: array[TIndivEventType] of string =
  ('Birth', 'Christening', 'Death', 'Burial', 'Cremation', 'Baptism', 'Bar Mitzvah',
    'Bas Mitzvah', 'Blessing', 'BaptismLDS', 'Adult Christening', 'Confirmation', 'Will',
    'Probate', 'Occupation', 'SSN', 'Census', 'Emigration', 'Immigration', 'Residence',
    'First Communion', 'Ordinance', 'Naturalization', 'Graduation', 'Retirement',
    'Adoption', 'Caste', 'Description', 'Education', 'ID Number', 'Nationality',
    'Number of Children', 'Number of Marriages', 'Possessions', 'Religion', 'Title', 'Event');

var
  Indiv: TIndivRecord;
  IndivBaseLvl: integer;
  FactBaseLvl: integer;
  FactDate: string;
  FactDesc: string;
  FactPlace: string;
  FactType: string; //stores the current fact type
  J: TIndivEventType;
  SkipEventCheck: boolean;

begin
  { Initialize these variables before looping }
  Indiv.IndKey := ansidequotedstr(GetTag(Gedcomlines.Strings[I]), '@');
  IndivBaseLvl := GetLevel(Line);

  { Loop through lines in the INDI record }
  repeat
    inc(I);
    SkipEventCheck := False;
    Line := Gedcomlines.Strings[I];

    Lvl := GetLevel(Line);
    Tag := GetTag(Line);
    Rest := GetRest(Line);

    { Grab basic info about individual }
    if Tag = 'NAME' then begin
      if Indiv.FullName = '' then
        Indiv.FullName := Rest
      else begin
        if Indiv.Aka = '' then
          Indiv.Aka := Rest
        else
          UpdateStatusLog('WARNING! Individual ' + Indiv.IndKey +
            ' has alternate Name entries.  Only the primary one will be used.');
      end;
      SkipEventCheck := True;
    end
    else if Tag = 'ALIA' then begin
      if Indiv.Aka = '' then
        Indiv.Aka := Rest
      else
        UpdateStatusLog('WARNING: Indiv ' + Indiv.IndKey +
          ' has an alternate Aka/Alias entry.  Only the primary one will be used.');
      SkipEventCheck := True;
    end
    else if Tag = 'NICK' then begin
      if Indiv.Aka = '' then
        Indiv.Aka := Rest
      else
        UpdateStatusLog('WARNING: Indiv ' + Indiv.IndKey +
          ' has an alternate Aka/Alias entry.  Only the primary one will be used.');
      SkipEventCheck := True;
    end
    else if Tag = 'TITL' then begin
      if Indiv.Title = '' then
        Indiv.Title := trim(Rest)
      else
        UpdateStatusLog('WARNING: Indiv ' + Indiv.IndKey +
          ' has an alternate Title entry.  Only the primary one will be used.');
      SkipEventCheck := True;
    end
    else if Tag = 'SEX' then begin
      if Indiv.Sex = '' then
        Indiv.Sex := Rest
      else
        UpdateStatusLog('WARNING: Indiv ' + Indiv.IndKey +
          ' has an alternate Sex entry.  Only the primary one will be used.');
      SkipEventCheck := True;
    end
    else if Tag = 'FAMC' then begin
      Indiv.FamKey := AnsiDequotedStr(Rest, '@');
      SkipEventCheck := True;
    end
    else if Tag = 'NOTE' then begin
      if Lvl <= succ(IndivBaseLvl) then begin
        if Indiv.NoteKey = '' then begin
          if (length(Rest) > 0) and (Rest[1] = '@') then begin
            Indiv.NoteKey := ansidequotedstr(Rest, '@');
          end
          else begin
            Indiv.NoteKey := 'N' + Indiv.IndKey;
            ProcessNoteRecord(I, Indiv.NoteKey);
          end;
        end
        else begin
          UpdateStatusLog('WARNING: Indiv ' + Indiv.IndKey +
            ' has an alternate Note entry.  Only the primary one will be used.');
        end;
      end;
      SkipEventCheck := True;
    end;

    { Look for Event Flags and begin }
    if SkipEventCheck = True then begin
      continue;
    end
    else begin
      for J := evtBirth to evtOther do
        if Tag = EventType[J] then begin
          FactType := EventDescrip[J];
          FactBaseLvl := Lvl;
          FactDate := '';
          FactPlace := '';
          FactDesc := '';
          if Rest <> '' then FactDesc := Rest;
          repeat
            inc(I);
            Line := Gedcomlines.Strings[I];
            Lvl := GetLevel(Line);
            Tag := GetTag(Line);
            if Tag = 'DATE' then
              FactDate := GetRest(Line)
            else if Tag = 'PLAC' then
              FactPlace := FactPlace + GetRest(Line)
            else if Tag = 'TYPE' then
              FactType := GetRest(Line)
            else if Tag = 'SOUR' then
              ProcessCitation(I);
          until Lvl <= FactBaseLvl;
          { Format data for IndivArray }
          if (FactDesc <> '') and (FactPlace <> '') then
            FactPlace := FactDesc + ' / ' + FactPlace
          else if (FactDesc <> '') and (FactPlace = '') then
            FactPlace := FactDesc;
          if FactDate = 'UNKNOWN' then
            FactDate := '';
          if not ((FactDate = '') and (FactPlace = '') or (FactDate = 'Private') or (FactPlace =
            'Y')) then begin
            { Write data to IndivArray }
            if FactIndex = length(FactArray) then
              setlength(FactArray, length(FactArray) + DefaultArrayInc, 7);
            FactArray[FactIndex, 0] := Indiv.IndKey;
            FactArray[FactIndex, 1] := FactType;
            FactArray[FactIndex, 2] := FactDate;
            FactArray[FactIndex, 3] := FactPlace;
            FactArray[FactIndex, 4] := inttostr(FactNum);
            inc(FactIndex);
            inc(FactNum);
          end;
          { Back up one line before proceeding and reset FactType flag }
          dec(I);
          FactType := '';
          FactDate := '';
          FactPlace := '';
          break;
        end; // if Tag = EventType[J]
    end; // for J := evtBirth to evtOther
  until Lvl = BaseLvl;

  { Format individual records }
  Indiv.Surname := ansidequotedstr(copy(Indiv.FullName, pos('/', Indiv.FullName), lastdelimiter('/',
    Indiv.FullName)), '/');
  Indiv.GivenName := trim(copy(Indiv.FullName, 1, pos('/', Indiv.FullName) - 1));
  Indiv.Aka := ansireplacestr(Indiv.Aka, '/', '');
  if Indiv.Sex = '' then
    Indiv.Sex := 'U'; // Work around error in FTW gedcom output

  { Write data to IndivArray }
  if IndevIndex = length(IndivArray) then begin
    setlength(IndivArray, length(IndivArray) + DefaultArrayInc, 7);
  end;
  IndivArray[IndevIndex, 0] := Indiv.IndKey;
  IndivArray[IndevIndex, 1] := trim(Indiv.Title);
  IndivArray[IndevIndex, 2] := trim(Indiv.Surname);
  IndivArray[IndevIndex, 3] := trim(Indiv.GivenName);
  IndivArray[IndevIndex, 4] := trim(Indiv.Aka);
  IndivArray[IndevIndex, 5] := Indiv.Sex;
  IndivArray[IndevIndex, 6] := Indiv.NoteKey;
  inc(IndevIndex);

  { Write data to RelatArray }
  if RelatIndex = length(RelatArray) then begin
    setlength(RelatArray, length(RelatArray) + DefaultArrayInc, 2);
  end;
  if Indiv.FamKey <> '' then begin
    RelatArray[RelatIndex, 0] := Indiv.IndKey;
    RelatArray[RelatIndex, 1] := Indiv.FamKey;
    inc(RelatIndex);
  end;

  // Back up one line before proceeding
  dec(I);
end;


{ ---------------------------------------------------------------------------- }

procedure ProcessNoteRecord(var I: integer; const RecordID: string);
var
  NOTEKey: string; //stores the NOTE record ID
  NOTEBaseLvl: integer;
  NOTEText: string; //stores the NOTE text
begin
  { Initialize variables }
  if RecordID = '0' then begin
    { This is normal }
    NOTEKey := GetTag(Gedcomlines.Strings[I]);
  end
  else begin
    { Process notes that do not have an identifier (i.e. PAF) }
    NoteKey := RecordID;
    Line := Gedcomlines.Strings[I];
    Rest := GetRest(Line);
    NoteText := Rest;
  end;
  NOTEBaseLvl := GetLevel(Line);

  { Loop through the Note record }
  repeat
    inc(I);
    Line := Gedcomlines.Strings[I];
    Lvl := GetLevel(Line);
    Tag := GetTag(Line);
    Rest := GetRest(Line);
    if Tag = 'CONC' then
      NoteText := NoteText + Rest
    else if (Tag = 'CONT') and (Rest <> '') then
      NoteText := NoteText + ParaSep + Rest
        { If next tag is another NOTE tag, then append it to the previous one (i.e. PAF) }
    else if (Tag = NoteKey) then
      NoteText := NoteText + ParaSep;
  until ((Lvl <= NOTEBaseLvl) and (Tag <> NoteKey));

  { Format record and add to Note array }
  if NoteIndex = length(NoteArray) then begin
    setlength(NoteArray, length(NoteArray) + DefaultArrayInc, 2);
  end;
  if RemoveQuotes = True then begin
    NoteText := ansireplacestr(NoteText, '"', '');
  end;
  if Wrap = True then begin
    NoteText := WrapText(NoteText, ParaSep, [' '], WrapCol);
  end;
  NoteArray[NoteIndex, 0] := ansidequotedstr(NOTEKey, '@');
  NoteArray[NoteIndex, 1] := NoteText;
  inc(NoteIndex);

  { Back up one line before proceeding }
  dec(I);
end;

{ ---------------------------------------------------------------------------- }
{ Process master source records }
procedure ProcessSOURRecord(var I: integer);
var
  SourKey: string; //stores the NOTE record ID
  SourTitl: string; //stores the SOUR record title
  SourPubl: string; //store the SOUR publication facts
  SourText: string; //stores the SOUR record text
  SourAuth: string; //stores the publication author
  SourCaln: string; //stores the call number
  SourNote: string; //stores link to additional notes
  SourALL: string; //stores all the information except SourKey
  LastRec: string; //stores the last record type
begin
  { Get the SOURKey }
  SourKey := ansidequotedstr(GetTag(Gedcomlines.Strings[I]), '@');

  repeat
    inc(I);
    Line := Gedcomlines.Strings[I];

    Lvl := GetLevel(Line);
    Tag := GetTag(Line);
    Rest := GetRest(Line);

    if Tag = 'TITL' then begin
      SourTitl := Rest;
      LastRec := Tag;
    end
    else if Tag = 'PUBL' then begin
      SourPubl := Rest;
      LastRec := Tag;
    end
    else if Tag = 'TEXT' then begin
      SourText := Rest;
      LastRec := Tag;
    end
    else if Tag = 'AUTH' then
      SourAuth := Rest
    else if Tag = 'CALN' then
      SourCaln := Rest
    else if Tag = 'NOTE' then
      if Rest[1] = '@' then
        SourNote := ansidequotedstr(Rest, '@')
      else begin
        SourText := Rest;
        LastRec := Tag;
      end;

    if Tag = 'CONC' then begin
      if LastRec = 'TITL' then
        SourTitl := SourTitl + ' ' + Rest
      else if LastRec = 'PUBL' then
        SourPubl := SourPubl + ' ' + Rest
      else if LastRec = 'TEXT' then
        SourText := SourText + ' ' + Rest
      else if LastRec = 'NOTE' then
        SourText := SourText + ' ' + Rest
    end;

    if Tag = 'CONT' then begin
      if LastRec = 'TITL' then
        SourTitl := SourTitl + ParaSep + Rest
      else if LastRec = 'PUBL' then
        SourPubl := SourPubl + ParaSep + Rest
      else if LastRec = 'TEXT' then
        SourText := SourText + ParaSep + Rest
      else if LastRec = 'NOTE' then
        SourText := SourText + ParaSep + Rest
    end;
  until BaseLvl = Lvl;

  // Format records for Source array
  if SourTitl <> '' then
    SourALL := SourALL + SourTitl;
  if SourAuth <> '' then
    SourALL := SourALL + ParaSep + 'Author: ' + SourAuth;
  if SourPubl <> '' then
    SourALL := SourALL + ParaSep + 'Published: ' + SourPubl;
  if SourCaln <> '' then
    SourAll := SourALL + ParaSep + 'Call Number: ' + SourCaln;
  if SourText <> '' then
    SourALL := SourALL + ParaSep + SourText;

  { Write data to Source array }
  if SourceIndex = length(SourceArray) then
    setlength(SourceArray, length(SourceArray) + DefaultArrayInc, 3);
  if RemoveQuotes = True then
    SourAll := ansireplacestr(SourAll, '"', '');
  SourceArray[SourceIndex, 0] := SourKey;
  SourceArray[SourceIndex, 1] := SourAll;
  SourceArray[SourceIndex, 2] := SourNote;
  inc(SourceIndex);
  dec(I);
end;

{ ---------------------------------------------------------------------------- }

procedure ProcessFAMRecord(var I: integer);
var
  FamKey: string; //the FAM record id
  Husband: string; //the husband's IndKey
  Wife: string; //the wife's IndKey
  BeginStatus: string;
  EndStatus: string; //marriage ending status
  FactType: string; //stores the event type
  FactDate: string; //stores the event date
  FactPlace: string; //stores the event place
  FactBaseLvl: integer;
  FamNote: string;
  Child: string;
begin
  // Get the FamKey
  FamKey := ansidequotedstr(GetTag(GedcomLines.Strings[I]), '@');

  repeat
    inc(I);
    Line := Gedcomlines.Strings[I];
    Lvl := GetLevel(Line);
    Tag := GetTag(Line);

    if Tag = 'HUSB' then
      Husband := ansidequotedstr(GetRest(Line), '@')
    else if Tag = 'WIFE' then
      Wife := ansidequotedstr(GetRest(Line), '@')
    else if Tag = 'NOTE' then
      FamNote := ansidequotedstr(GetRest(Line), '@')

    else if Tag = 'CHIL' then begin
      Child := ansidequotedstr(GetRest(Line), '@');
      { Write data to ChildArray }
      if ChildIndex = length(ChildArray) then begin
        setlength(ChildArray, length(ChildArray) + DefaultArrayInc, 2);
      end;
      ChildArray[ChildIndex, 0] := FamKey;
      ChildArray[ChildIndex, 1] := Child;
      inc(ChildIndex);
    end


    else if Tag = 'DIV' then begin
      EndStatus := 'Divorced';
      FactType := 'Divorced';
    end
    else if Tag = 'ANUL' then begin
      EndStatus := 'Annulment';
      FactType := 'Annulment';
    end
    else if Tag = '_MEND' then // FTW style Marriage End Status tag
      EndStatus := GetRest(Line)
    else if Tag = '_STAT' then // FTW style Marriage Begin Status tag
      EndStatus := GetRest(Line)
    else if Tag = 'MARR' then begin
      FactType := 'Marriage';
      BeginStatus := 'Married';
    end
    else if Tag = 'DIVF' then
      FactType := 'Divorce Filed'
    else if Tag = 'CENS' then
      FactType := 'Census'
    else if Tag = 'ENGA' then
      FactType := 'Engagement'
    else if Tag = 'MARB' then
      FactType := 'Marriage Bann'
    else if Tag = 'MARC' then
      FactType := 'Marriage Contract'
    else if Tag = 'MARL' then
      FactType := 'Marriage License'
    else if Tag = 'MARS' then
      FactType := 'Marriage Settlement'
    else if Tag = 'EVEN' then
      FactType := 'Event';

    if FactType <> '' then begin
      FactBaseLvl := Lvl;
      FactDate := '';
      FactPlace := '';
      repeat
        inc(I);
        Line := Gedcomlines.Strings[I];
        Lvl := GetLevel(Line);
        Tag := GetTag(Line);
        if (Tag = 'DATE') then begin
          FactDate := GetRest(Line);
        end
        else if (Tag = 'PLAC') then begin
          FactPlace := GetRest(Line);
        end
        else if (Tag = 'TYPE') then begin
          FactType := GetRest(Line);
          { Attempt to find BeginStatus }
          if (FactType = 'Friends') or (FactType = 'Single') or (FactType = 'Unmarried')
            or (FactType = 'Partners') or (FactType = 'Unknown') then
              BeginStatus := FactType;
        end
        else if (Tag = 'SOUR') then begin
          ProcessCitation(I);
        end;
      until Lvl <= FactBaseLvl;

      { Format records for FactList }
      if FactType = 'Private-Begin' then begin
        FactType := 'Marriage';
      end;
      { Write data to FactArray }
      if FactIndex = length(FactArray) then begin
        setlength(FactArray, length(FactArray) + DefaultArrayInc, 7);
      end;
      FactArray[FactIndex, 0] := FamKey;
      FactArray[FactIndex, 1] := FactType;
      FactArray[FactIndex, 2] := FactDate;
      FactArray[FactIndex, 3] := FactPlace;
      FactArray[FactIndex, 4] := inttostr(FactNum);
      inc(FactIndex);
      inc(FactNum);

      // Back up one line before proceeding and reset FactType flag
      dec(I);
      //inc(FactNum);
      FactType := '';
      FactDate := '';
      FactPlace := '';
    end;
  until BaseLvl = Lvl;

  // Format records and add to Family array
  if FamIndex = length(FamArray) then begin
    setlength(FamArray, length(FamArray) + DefaultArrayInc, 6);
  end;
  if BeginStatus = '' then
    BeginStatus := 'Married';
  FamArray[FamIndex, 0] := FamKey;
  FamArray[FamIndex, 1] := Husband;
  FamArray[FamIndex, 2] := Wife;
  FamArray[FamIndex, 3] := BeginStatus;
  FamArray[FamIndex, 4] := EndStatus;
  FamArray[FamIndex, 5] := Famnote;
  inc(FamIndex);
  dec(I);
end;

{ ---------------------------------------------------------------------------- }

procedure ProcessCitation(var I: integer);
var
  CitationBaseLvl: integer;
  SourCitePage: string;
  SourCiteText: string;
  MasterSour: string;

begin
  Line := gedcomlines.strings[I];
  Lvl := GetLevel(Line);
  CitationBaseLvl := Lvl;
  SourCitePage := '';
  SourCiteText := '';
  MasterSour := ansidequotedstr(GetRest(Line), '@');
  if MasterSour = '' then
    UpdateStatusLog('WARNING! Source Citation ' + inttostr(FactNum) + ' has no Master Source.');
  repeat
    inc(I);
    Line := Gedcomlines.Strings[I];
    Lvl := GetLevel(Line);
    Tag := GetTag(Line);
    Rest := GetRest(Line);
    if Tag = 'PAGE' then
      SourCitePage := Rest
    else if Tag = 'TEXT' then
      SourCiteText := Rest
    else if Tag = 'CONC' then
      SourCiteText := SourCiteText + Rest
    else if Tag = 'CONT' then
      if SourCiteText <> '' then
        SourCiteText := SourCiteText + ParaSep + Rest
      else
        SourCiteText := Rest;
  until Lvl <= CitationBaseLvl;
  { Format data and write to CitationList }
  if SourCitePage <> '' then
    SourCiteText := SourCitePage + ParaSep + SourCiteText;
  if CitationIndex = length(CitationArray) then
    setlength(CitationArray, length(CitationArray) + DefaultArrayInc, 3);
  if RemoveQuotes = True then
    SourCiteText := ansireplacestr(SourCiteText, '"', '');
  CitationArray[CitationIndex, 0] := inttostr(FactNum);
  CitationArray[CitationIndex, 1] := MasterSour;
  CitationArray[CitationIndex, 2] := SourCiteText;
  inc(CitationIndex);
  dec(I);
end;

{ ---------------------------------------------------------------------------- }

procedure ProcessHeader(var I: integer);
var
  LastTag: string;
begin
  inc(I);
  Line := GedcomLines.Strings[I];
  Lvl := GetLevel(Line);
  while Lvl > BaseLvl do begin
    Line := GedcomLines.Strings[I];
    Lvl := GetLevel(Line);
    Tag := GetTag(Line);
    Rest := GetRest(Line);
    if Tag = 'SOUR' then begin
      UpdateStatusLog('Source App: ' + Rest);
      LastTag := Tag;
    end
    else if Tag = 'VERS' then begin
      if LastTag = 'SOUR' then begin
        UpdateStatusLog('Source App Version: ' + Rest);
        LastTag := '';
      end;
    end;
    inc(I);
  end;
  dec(I);
  dec(I);
end;

{ ---------------------------------------------------------------------------- }

end.

