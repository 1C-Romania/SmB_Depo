#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	AttributesToExclude = New Array;
	
	If Not User Then
		AttributesToExclude.Add("Author");
	EndIf;
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, AttributesToExclude);
	
	If Description <> "" AND ReportsVariants.DescriptionIsBooked(Report, Ref, Description) Then
		Cancel = True;
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='""%1"" is occupied, you must specify another name.';ru='""%1"" занято, необходимо указать другое наименование.'"),
				Description
			),
			,
			"Description");
	EndIf;
EndProcedure

Procedure BeforeWrite(Cancel)
	If AdditionalProperties.Property("PredefinedOnesFilling") Then
		CheckFillingPredefined(Cancel);
	EndIf;
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DeletionMarkIsChangedByUser = (
		Not IsNew()
		AND DeletionMark <> Ref.DeletionMark
		AND Not AdditionalProperties.Property("PredefinedOnesFilling"));
	
	If Not User AND DeletionMarkIsChangedByUser Then
		If DeletionMark Then
			ErrorText = NStr("en='You can not mark the predefined report variant for deletion.';ru='Пометка на удаление предопределенного варианта отчета запрещена.'");
		Else
			ErrorText = NStr("en='You can not uncheck the predefined report variant for deletion.';ru='Снятие пометки удаления предопределенного варианта отчета запрещена.'");
		EndIf;
		ReportsVariants.ErrorByVariant(Ref, ErrorText);
		Raise ErrorText;
	EndIf;
	
	If Not DeletionMark AND DeletionMarkIsChangedByUser Then
		DescriptionIsBooked = ReportsVariants.DescriptionIsBooked(Report, Ref, Description);
		VariantKeyIsBooked  = ReportsVariants.VariantKeyIsBooked(Report, Ref, VariantKey);
		If DescriptionIsBooked OR VariantKeyIsBooked Then
			ErrorText = NStr("en='Error of unchecking the report variant deletion mark:';ru='Ошибка снятия пометки удаления варианта отчета:'");
			If DescriptionIsBooked Then
				ErrorText = ErrorText + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Name ""%1"" is already occupied with another variant of this report.';ru='Наименование ""%1"" уже занято другим вариантом этого отчета.'"),
					Description);
			Else
				ErrorText = ErrorText + StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Variant key ""%1"" is already occupied with another variant of this report.';ru='Ключ варианта ""%1"" уже занят другим вариантом этого отчета.'"),
					VariantKey);
			EndIf;
			ErrorText = ErrorText + NStr("en='Before unchecking the deletion mark"
"of the report variant it is necessary to install the deletion mark of the controversial report variant.';ru='Перед снятием пометки удаления варианта отчета"
"необходимо установить пометку удаления конфликтующего варианта отчета.'");
			ReportsVariants.ErrorByVariant(Ref, ErrorText);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	// Deletion of items marked for deletion from the subsystems tabular section.
	RowToDeleteArray = New Array;
	For Each RowOfPlacement IN Placement Do
		If RowOfPlacement.Subsystem.DeletionMark = True Then
			RowToDeleteArray.Add(RowOfPlacement);
		EndIf;
	EndDo;
	For Each RowOfPlacement IN RowToDeleteArray Do
		Placement.Delete(RowOfPlacement);
	EndDo;
	
	// Filling the attributes "FieldNames" and "ParametersAndFiltersNames".
	IndexSettings();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure IndexSettings()
	If User Or ReportType = Enums.ReportsTypes.Additional Then
		Try
			ReportsVariants.IndexSchemaContent(ThisObject);
		Except
			ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Failed to index the ""%1"" variant scheme of the ""%2"" report:';ru='Не удалось проиндексировать схему варианта ""%1"" отчета ""%2"":'"),
				VariantKey,
				String(Report));
			ReportsVariants.ErrorByVariant(Ref, ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo()));
		EndTry;
	Else
		// For predefined reports variants the data is stored in the undivided catalog.
		If FieldNames <> "" Then
			FieldNames = "";
		EndIf;
		If ParametersAndFiltersNames <> "" Then
			ParametersAndFiltersNames = "";
		EndIf;
	EndIf;
EndProcedure

// Fills the parent of the variant report based on the report references and predefined settings.
Procedure FillParent() Export
	QueryText =
	"SELECT ALLOWED TOP 1
	|	Predetermined.Ref AS PredefinedVariant
	|INTO TTPredefined
	|FROM
	|	Catalog.PredefinedReportsVariants AS Predetermined
	|WHERE
	|	Predetermined.Report = &Report
	|	AND Predetermined.DeletionMark = FALSE
	|	AND Predetermined.GroupByReport
	|
	|ORDER BY
	|	Predetermined.Enabled DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	ReportsVariants.Ref
	|FROM
	|	TTPredefined AS TTPredefined
	|		INNER JOIN Catalog.ReportsVariants AS ReportsVariants
	|		ON TTPredefined.PredefinedVariant = ReportsVariants.PredefinedVariant
	|WHERE
	|	ReportsVariants.DeletionMark = FALSE";
	Query = New Query;
	Query.SetParameter("Report", Report);
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Parent = Selection.Ref;
	EndIf;
EndProcedure

// Basic checks of the data correctness of the predefined reports.
Procedure CheckFillingPredefined(Cancel)
	If DeletionMark Or Not Predefined Then
		Return;
	ElsIf Not ValueIsFilled(Report) Then
		ErrorText = NotFilledField("Report");
	ElsIf Not ValueIsFilled(ReportType) Then
		ErrorText = NotFilledField("ReportType");
	ElsIf Not ReportsTypesMatch() Then
		ErrorText = ControversialFieldValues("ReportType", "Report");
	ElsIf ReportType = Enums.ReportsTypes.Internal
		AND Not ValueIsFilled(PredefinedVariant) Then
		ErrorText = NotFilledField("PredefinedVariant");
	Else
		Return;
	EndIf;
	Cancel = True;
	ReportsVariants.ErrorByVariant(Ref, ErrorText);
EndProcedure

Function NotFilledField(FieldName)
	Return StrReplace(NStr("en='The field ""%1"" is not filled.';ru='Не заполнено поле ""%1""'"), "%1", FieldName);
EndFunction

Function ReportsTypesMatch()
	If TypeOf(Report) = Type("CatalogRef.MetadataObjectIDs") Then
		ExpectedType = Enums.ReportsTypes.Internal;
	ElsIf TypeOf(Report) = Type("String") Then
		ExpectedType = Enums.ReportsTypes.External;
	Else
		ExpectedType = Enums.ReportsTypes.Additional;
	EndIf;
	Return ReportType = ExpectedType;
EndFunction

Function ControversialFieldValues(FieldName1, FieldName2)
	Return StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Conflicting values of fields ""%1"" and ""%2"".';ru='Противоречивые значения полей ""%1"" и ""%2""'"),
		FieldName1,
		FieldName2
	);
EndFunction

#EndRegion

#EndIf
