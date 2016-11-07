////////////////////////////////////////////////////////////////////////////////
// Subsystem "Access management".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Servicing tables AccessKinds and AccessValues in edit forms.

// Only for internal use.
Function FormDataOfUserChoice(Val Text,
                                             Val IcludingGroups = True,
                                             Val IncludingExternalUsers = Undefined,
                                             Val WithoutUsers = False) Export
	
	Return Users.FormDataOfUserChoice(
		Text,
		IcludingGroups,
		IncludingExternalUsers,
		WithoutUsers);
	
EndFunction

// Returns the list of access values not marked for deletion.
//  Used in event handlers TextEntryEnd and AutoPick.
//
// Parameters:
//  Text         - String - characters entered by the user.
//  IcludingGroups - Boolean - if True, then include groups of users and external users.
//  AccessKind    - Refs - empty reference of access value main type,
//                - String - name of access kind values of which are selected.
//
Function FormDataOfAccessValueChoice(Val Text, Val AccessKind, IcludingGroups = True) Export
	
	AccessTypeProperties = AccessManagementService.AccessTypeProperties(AccessKind);
	If AccessTypeProperties = Undefined Then
		Return New ValueList;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Text", Text + "%");
	Query.SetParameter("IcludingGroups", IcludingGroups);
	Query.Text =
	"SELECT
	|	PresentationsOfEnums.Ref AS Ref,
	|	PresentationsOfEnums.Description AS Description
	|INTO EnumsPresentations
	|FROM
	|	&EnumsPresentations AS EnumsPresentations
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	"""" AS Description
	|WHERE
	|	FALSE";
	
	EnumsPresentationsOuery = New Query;
	EnumsPresentationsOuery.Text =
	"SELECT
	|	"""" AS Ref,
	|	"""" AS Description
	|WHERE
	|	FALSE";
	
	For Each Type IN AccessTypeProperties.SelectedValuesTypes Do
		MetadataObject = Metadata.FindByType(Type);
		FullTableName = MetadataObject.FullName();
		
		If (     Metadata.Catalogs.Contains(MetadataObject)
		       OR Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) )
		   AND MetadataObject.Hierarchical
		   AND MetadataObject.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems
		   AND Not IcludingGroups Then
			
			ConditionForGroup = "NOT Table.IsFolder";
		Else
			ConditionForGroup = "True";
		EndIf;
		
		If Metadata.Enums.Contains(MetadataObject) Then
			QueryText =
			"SELECT
			|	Table.Ref AS Ref,
			|	PRESENTATION(Table.Ref) AS Description
			|FROM
			|	&FullTableName AS Table";
			QueryText = StrReplace(QueryText, "&FullTableName", FullTableName);
			
			EnumsPresentationsOuery.Text = EnumsPresentationsOuery.Text
				+ Chars.LF + Chars.LF + " UNION ALL " + Chars.LF + Chars.LF
				+ QueryText;
		Else
			QueryText = 
			"SELECT
			|	Table.Ref AS Ref,
			|	Table.Description AS Description
			|FROM
			|	&FullTableName AS Table
			|WHERE
			|	(NOT Table.DeletionMark)
			|	AND Table.Description LIKE &Text
			|	AND &ConditionForGroup";
			QueryText = StrReplace(QueryText, "&FullTableName", FullTableName);
			QueryText = StrReplace(QueryText, "&ConditionForGroup", ConditionForGroup);
			QueryText = StrReplace(QueryText, "Table.Description",
				"Table." + PresentationField(MetadataObject));
			
			Query.Text = Query.Text
				+ Chars.LF + Chars.LF + " UNION ALL " + Chars.LF + Chars.LF
				+ QueryText;
		EndIf;
	EndDo;
	
	Query.SetParameter("EnumsPresentations",
		EnumsPresentationsOuery.Execute().Unload());
	
	Query.Text = Query.Text
		+ Chars.LF + Chars.LF + " UNION ALL "  + Chars.LF + Chars.LF;
	
	Query.Text = Query.Text +
	"SELECT
	|	PresentationsOfEnums.Ref,
	|	PresentationsOfEnums.Description
	|FROM
	|	EnumsPresentations AS EnumsPresentations
	|WHERE
	|	PresentationsOfEnums.Description LIKE &Text";
	
	ChoiceData = New ValueList;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.Description);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

Function PresentationField(MetadataObject)
	
	PresentationField = "Description";
	
	If Metadata.ExchangePlans.Contains(MetadataObject) Then
		
		If MetadataObject.MainPresentation
			= Metadata.ObjectProperties.ExchangePlanMainPresentation.InCodeForm Then
			
			PresentationField = "Code";
		EndIf;
		
	ElsIf Metadata.Catalogs.Contains(MetadataObject) Then
		
		If MetadataObject.MainPresentation
			= Metadata.ObjectProperties.CatalogMainPresentation.InCodeForm Then
			
			PresentationField = "Code";
		EndIf;
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		
		If MetadataObject.MainPresentation
			= Metadata.ObjectProperties.CharacteristicKindMainPresentation.InCodeForm Then
			
			PresentationField = "Code";
		EndIf;
		
	ElsIf Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
		
		If MetadataObject.MainPresentation
			= Metadata.ObjectProperties.AccountMainPresentation.InCodeForm Then
			
			PresentationField = "Code";
		EndIf;
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(MetadataObject) Then
		
		If MetadataObject.MainPresentation
			= Metadata.ObjectProperties.CalculationKindMainPresentation.InCodeForm Then
			
			PresentationField = "Code";
		EndIf;
		
	EndIf;
	
	Return PresentationField;
	
EndFunction

#EndRegion
