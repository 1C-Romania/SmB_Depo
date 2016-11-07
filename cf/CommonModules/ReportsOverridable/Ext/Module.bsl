////////////////////////////////////////////////////////////////////////////////
// Server events of report forms.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// IN this procedure you should describe additional dependencies
//   of metadata objects configuration that will be used for connection of reports settings.
//
// Parameters:
//   MetadataObjectsLinks - ValueTable - Connections table.
//       * SubordinateAttribute - String - Attribute name of the subordinate metadata object.
//       * SubordinateType      - Type    - Type of the subordinate metadata object.
//       * LeadingType          - Type    - Type of the leading metadata object.
//
Procedure SupplementMetadataObjectsLinks(MetadataObjectsLinks) Export
	
	
	
EndProcedure

// Called in the form of report before the setting output.
//
// Parameters:
//   Form - ManagedForm, Undefined - Report form.
//   SettingProperty - Structure - Description of the report settings that will be displayed in the report form.
//       * TypeDescription - TypeDescription -
//           Setting type.
//       *ValuesForSelection - ValueList -
//           Objects that will be offered to a user in the selection list.
//           Expands list of objects already selected by a user.
//       * SelectionValueQuery - Query -
//           Returns objects to expand ValuesForSelection.
//           As a first column (with 0 index)
//           should be selected an object which you should add to ValuesForSelection.Value.
//           To disable
//           auto fill, you should write an empty row to the QueryValuesSelection.Text property.
//       * RestrictSelectionWithSpecifiedValues - Boolean -
//           If True, then user's selection will be
//           limited by values specified in ValuesForSelection (its end state).
//
Procedure OnDefineSelectionParameters(Form, SettingProperty) Export
	
EndProcedure

// Called in the handler of the report form eponymous event after execution of the form code.
//
// Parameters:
//   Form - ManagedForm - Report form.
//   Cancel - Passed from the handler parameters "as is."
//   StandardProcessing - Passed from the handler parameters "as is."
//
// See also:
//   ManagedForm.OnCeateOnServer in syntax helper.
//
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	Form.Items.QuickSettings.BackColor = StyleColors.QuickSettingsGroupBackground;
	Form.Items.ReportSpreadsheetDocument.ViewScalingMode = ViewScalingMode.Normal;
	
EndProcedure

// Called in the handler of the report form eponymous event after execution of the form code.
//
// Parameters:
//   Form - ManagedForm - Report form.
//   NewSettingsDC - DataCompositionSettings - Settings for import to the settings linker.
//
// See also:
//   Extension of the controlled form for report.OnLoadVariantOnServer in syntax helper.
//
Procedure BeforeLoadVariantAtServer(Form, NewSettingsDC) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Outdated procedures and functions.

// Expired: you should use the similar procedure in the report object module.
Procedure OnLoadVariantAtServer(Form, NewSettingsDC) Export
	
EndProcedure

// Expired: you should use the similar procedure in the report object module.
Procedure OnLoadUserSettingsAtServer(Form, NewDCUserSettings) Export
	
EndProcedure

// Expired: you should use the similar procedure in the report object module.
Procedure BeforeFillingQuickSettingsPanel(Form, FillingParameters) Export
	
EndProcedure

// Expired: you should use the similar procedure in the report object module.
Procedure AfterFillingQuickSettingsPanel(Form, FillingParameters) Export
	
EndProcedure

// Expired: you should use the similar procedure in the report object module.
Procedure ContextServerCall(Form, Key, Parameters, Result) Export
	
EndProcedure

#EndRegion
