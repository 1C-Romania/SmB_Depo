#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Writes setting table in the register data by specified measurements.
Procedure WriteSettingsPackage(SettingsTable, Dimensions, Resources, DeleteOld) Export
	
	RecordSet = CreateRecordSet();
	For Each KeyAndValue IN Dimensions Do
		RecordSet.Filter[KeyAndValue.Key].Set(KeyAndValue.Value, True);
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	For Each KeyAndValue IN Resources Do
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	If Not DeleteOld Then
		RecordSet.Read();
		OldRecords = RecordSet.Unload();
		SearchByDimensions = New Structure("User, Subsystem, Variant");
		For Each OldRecord IN OldRecords Do
			FillPropertyValues(SearchByDimensions, OldRecord);
			If SettingsTable.FindRows(SearchByDimensions).Count() = 0 Then
				FillPropertyValues(SettingsTable.Add(), OldRecord);
			EndIf;
		EndDo;
	EndIf;
	RecordSet.Load(SettingsTable);
	RecordSet.Write(True);
	
EndProcedure

// Clears settings by report variant.
Procedure ResetSettings(VariantRef = Undefined) Export
	
	RecordSet = CreateRecordSet();
	If VariantRef <> Undefined Then
		RecordSet.Filter.Variant.Set(VariantRef, True);
	EndIf;
	RecordSet.Write(True);
	
EndProcedure

// Clears settings of specified (or current) user in section.
Procedure ResetUserSettingsSection(SectionRef, User = Undefined) Export
	If User = Undefined Then
		User = Users.CurrentUser();
	EndIf;
	
	Query = New Query;
	Query.SetParameter("SectionRef", SectionRef);
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	IOM.Ref
	|FROM
	|	Catalog.MetadataObjectIDs AS IOM
	|WHERE
	|	IOM.Ref IN HIERARCHY(&SectionRef)";
	SubsystemArray = Query.Execute().Unload().UnloadColumn("Ref");
	
	RecordSet = CreateRecordSet();
	RecordSet.Filter.User.Set(User, True);
	For Each SubsystemRef IN SubsystemArray Do
		RecordSet.Filter.Subsystem.Set(SubsystemRef, True);
		RecordSet.Write(True);
	EndDo;
EndProcedure

#EndRegion

#EndIf