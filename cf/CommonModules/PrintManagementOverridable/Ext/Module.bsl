////////////////////////////////////////////////////////////////////////////////
// Subsystem "Print".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Overrides a table of available formats for saving tabular document.
// Called from CommonUse.TabularDocumentSavingFormatsSettings ()
//
// Parameters:
//  FormatsTable - ValueTable:
//                   *  SpreadsheetDocumentFileType - SpreadsheetDocumentFileType                - value
//                                                                                                 in
//                                                                                                 the
//                                                                                                 platform corresponding format;
//                   *  Ref                        - EnumRef.SaveReportFormats                   - ref
//                                                                                                 to metadata
//                                                                                                 where
//                                                                                                 presentation is stored;
//                   *  Presentation               - String -                                    - presentation
//                                                             file type (populated from enum);
//                   *  Extension                  - String -                                    - file type
//                                                             for the operating system;
//                   *  Picture                    - Picture                                     - icon format.
//
Procedure OnSpreadsheetDocumentSavingFormatsSettingsFilling(FormatsTable) Export
	
EndProcedure

// Overrides the list of print commands received by the PrintManagement.PrintCommandsForms function.
Procedure BeforeAddingPrintCommands(FormName, PrintCommands, StandardProcessing) Export
	
EndProcedure

#EndRegion
