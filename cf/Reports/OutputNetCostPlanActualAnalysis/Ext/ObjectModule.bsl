#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	Var TableOutput;
	Var TablePlanCostsOnOutput;
	
	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	SmallBusinessReports.SetReportAppearanceTemplate(ReportSettings);
	SmallBusinessReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	ParameterValues = CompositionTemplate.ParameterValues;
	DataCompositionParameter = ParameterValues.Find("EndOfPeriod");
	If Not DataCompositionParameter = Undefined Then
		
		If TypeOf(DataCompositionParameter.Value) = Type("Date")
			AND DataCompositionParameter.Value = Date(1,1,1) THEN
		
			DataCompositionParameter.Value = Date(3999,12,31);
			
		EndIf;
	
	EndIf;
	
	GenerateTableOutputAndPlanCosts(TableOutput, TablePlanCostsOnOutput, ParameterValues);
	
	CalculateCostPricePlannedCostsOnOutput(TablePlanCostsOnOutput);
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("TableOutput", TableOutput);
	ExternalDataSets.Insert("TablePlanCostsOnOutput", TablePlanCostsOnOutput);
	
	//Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	//Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	//Indicate the output begin
	OutputProcessor.BeginOutput();
	TableFixed = False;
	
	ResultDocument.FixedTop = 0;
	//Main cycle of the report output
	While True Do
		//Get the next item of a composition result
		ResultItem = CompositionProcessor.Next();
		
		If ResultItem = Undefined Then
			//The next item is not received - end the output cycle
			Break;
		Else
			// Fix header
			If  Not TableFixed 
				  AND ResultItem.ParameterValues.Count() > 0 
				  AND TypeOf(SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then
				
				TableFixed = True;
				ResultDocument.FixedTop = ResultDocument.TableHeight;
			
			EndIf;
			//Item is received - output it using an output processor
			OutputProcessor.OutputItem(ResultItem);
		EndIf;
	EndDo;
	
	OutputProcessor.EndOutput();
	
EndProcedure

Procedure GenerateTableOutputAndPlanCosts(TableOutput, TablePlanCostsOnOutput, ParameterValues)
	
	PeriodOpenDate = Date(1,1,1);
	EndDatePeriod = Date(3999,12,31);
	
	DataCompositionParameter = ParameterValues.Find("BeginOfPeriod");
	If Not DataCompositionParameter = Undefined 
		AND TypeOf(DataCompositionParameter.Value) = Type("Date")
		AND DataCompositionParameter.Value <> Date(1,1,1) THEN
		
		PeriodOpenDate = DataCompositionParameter.Value;
	EndIf;
	
	DataCompositionParameter = ParameterValues.Find("EndOfPeriod");
	If Not DataCompositionParameter = Undefined 
		AND TypeOf(DataCompositionParameter.Value) = Type("Date")
		AND DataCompositionParameter.Value <> Date(1,1,1) THEN
		
		EndDatePeriod = DataCompositionParameter.Value;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("BeginOfPeriod", PeriodOpenDate);
	Query.SetParameter("EndOfPeriod",  EndDatePeriod);
	
	Query.Text = 
	"SELECT ALLOWED
	|	ProductReleaseTurnovers.Company AS Company,
	|	ProductReleaseTurnovers.StructuralUnit AS Division,
	|	ProductReleaseTurnovers.ProductsAndServices AS Products,
	|	ProductReleaseTurnovers.Characteristic AS ProductCharacteristic,
	|	ProductReleaseTurnovers.Batch AS BatchProducts,
	|	ProductReleaseTurnovers.CustomerOrder AS CustomerOrder,
	|	ProductReleaseTurnovers.Specification AS ProductionSpecification,
	|	ProductReleaseTurnovers.QuantityTurnover AS ProductsQuantity,
	|	NULL AS ProductsAndServices
	|INTO TemporaryTableOutput
	|FROM
	|	AccumulationRegister.ProductRelease.Turnovers(&BeginOfPeriod, &EndOfPeriod, , ProductsAndServices.ProductsAndServicesType <> VALUE(Enum.ProductsAndServicesTypes.Service)) AS ProductReleaseTurnovers
	|
	|INDEX BY
	|	Products,
	|	ProductCharacteristic,
	|	ProductionSpecification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductRelease.Company,
	|	ProductRelease.Division,
	|	ProductRelease.Products,
	|	ProductRelease.ProductCharacteristic,
	|	ProductRelease.BatchProducts,
	|	ProductRelease.CustomerOrder,
	|	ProductRelease.ProductionSpecification,
	|	ProductRelease.ProductsQuantity
	|FROM
	|	TemporaryTableOutput AS ProductRelease
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductRelease.Company,
	|	ProductRelease.Division,
	|	ProductRelease.Products,
	|	ProductRelease.ProductCharacteristic,
	|	ProductRelease.BatchProducts,
	|	ProductRelease.CustomerOrder,
	|	ProductRelease.ProductionSpecification AS SpecificationProductRelease,
	|	CASE
	|		WHEN ProductRelease.ProductionSpecification = VALUE(Catalog.Specifications.EmptyRef)
	|			THEN ProductRelease.Products.Specification
	|		ELSE ProductRelease.ProductionSpecification
	|	END AS ProductionSpecification,
	|	ProductRelease.ProductsQuantity AS QuantityProductRelease,
	|	SpecificationsContent.ProductsAndServices,
	|	SpecificationsContent.Characteristic,
	|	CASE
	|		WHEN SpecificationsContent.MeasurementUnit REFS Catalog.UOM
	|			THEN SpecificationsContent.Quantity * CAST(SpecificationsContent.MeasurementUnit AS Catalog.UOM).Factor
	|		ELSE SpecificationsContent.Quantity
	|	END / ISNULL(SpecificationsContent.ProductsQuantity, 1) * ProductRelease.ProductsQuantity AS Quantity,
	|	SpecificationsContent.Specification,
	|	SpecificationsContent.ContentRowType
	|INTO TemporaryTableContentRelease
	|FROM
	|	TemporaryTableOutput AS ProductRelease
	|		LEFT JOIN Catalog.Specifications.Content AS SpecificationsContent
	|		ON (NOT SpecificationsContent.Ref.DeletionMark)
	|			AND (CASE
	|				WHEN ProductRelease.ProductionSpecification = VALUE(Catalog.Specifications.EmptyRef)
	|					THEN ProductRelease.Products.Specification
	|				ELSE ProductRelease.ProductionSpecification
	|			END = SpecificationsContent.Ref)
	|			AND ProductRelease.Products = SpecificationsContent.Ref.Owner
	|			AND ProductRelease.ProductCharacteristic = SpecificationsContent.Ref.ProductCharacteristic
	|			AND (SpecificationsContent.ContentRowType <> VALUE(Enum.SpecificationContentRowTypes.Expense))
	|			AND (SpecificationsContent.ProductsAndServices <> ProductRelease.Products)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompositionOutput.Company,
	|	CompositionOutput.Division,
	|	CompositionOutput.Products,
	|	CompositionOutput.ProductCharacteristic,
	|	CompositionOutput.BatchProducts,
	|	CompositionOutput.CustomerOrder,
	|	CompositionOutput.SpecificationProductRelease,
	|	CompositionOutput.ProductionSpecification,
	|	CompositionOutput.QuantityProductRelease,
	|	CompositionOutput.ProductsAndServices,
	|	CompositionOutput.Characteristic,
	|	CompositionOutput.Quantity,
	|	CompositionOutput.Specification,
	|	CompositionOutput.ContentRowType
	|FROM
	|	TemporaryTableContentRelease AS CompositionOutput
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CompositionOutput.ProductsAndServices AS ProductsAndServicesNode,
	|	CompositionOutput.Characteristic AS CharacteristicNode,
	|	CompositionOutput.Specification AS SpecificationNode
	|FROM
	|	TemporaryTableContentRelease AS CompositionOutput
	|WHERE
	|	CompositionOutput.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Node)";
	
	Result = Query.ExecuteBatch();
	
	TableOutput = Result[1].Unload();
	TablePlanCostsOnOutput = Result[3].Unload();
	TableNodeSpecificationToExplosion = Result[4].Unload();
	
	While TableNodeSpecificationToExplosion.Count() > 0 Do
		
		ExplosionNodesSpecifications(TableNodeSpecificationToExplosion, TablePlanCostsOnOutput);
		
	EndDo;
	
EndProcedure

Procedure ExplosionNodesSpecifications(TableNodeSpecificationToExplosion, TablePlanCostsOnOutput)
	
	Query = New Query;
	Query.SetParameter("TableNodeSpecificationToExplosion", TableNodeSpecificationToExplosion);
	Query.SetParameter("TablePlanCostsOnOutput", TablePlanCostsOnOutput);
	
	Query.Text = 
	"SELECT DISTINCT
	|	TableNodeSpecificationToExplosion.ProductsAndServicesNode AS ProductsAndServicesNode,
	|	TableNodeSpecificationToExplosion.CharacteristicNode AS CharacteristicNode,
	|	TableNodeSpecificationToExplosion.SpecificationNode AS SpecificationNode
	|INTO Tu_TableNodeSpecificationToExplosion
	|FROM
	|	&TableNodeSpecificationToExplosion AS TableNodeSpecificationToExplosion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SpecificationsContent.Ref.Owner AS ProductsAndServicesNode,
	|	SpecificationsContent.Ref AS SpecificationNode,
	|	SpecificationsContent.Ref.ProductCharacteristic AS CharacteristicNode,
	|	SpecificationsContent.ProductsAndServices,
	|	SpecificationsContent.Characteristic,
	|	CASE
	|		WHEN SpecificationsContent.MeasurementUnit REFS Catalog.UOM
	|			THEN SpecificationsContent.Quantity * CAST(SpecificationsContent.MeasurementUnit AS Catalog.UOM).Factor
	|		ELSE SpecificationsContent.Quantity
	|	END / ISNULL(SpecificationsContent.ProductsQuantity, 1) AS Quantity,
	|	SpecificationsContent.Specification,
	|	SpecificationsContent.ContentRowType
	|INTO TemporaryTableCompositionNodes
	|FROM
	|	Catalog.Specifications.Content AS SpecificationsContent
	|WHERE
	|	Not SpecificationsContent.Ref.DeletionMark
	|	AND (SpecificationsContent.Ref.Owner, SpecificationsContent.Ref.ProductCharacteristic, SpecificationsContent.Ref) In
	|			(SELECT
	|				Tu_TableNodeSpecificationToExplosion.ProductsAndServicesNode,
	|				Tu_TableNodeSpecificationToExplosion.CharacteristicNode,
	|				Tu_TableNodeSpecificationToExplosion.SpecificationNode
	|			FROM
	|				Tu_TableNodeSpecificationToExplosion)
	|	AND SpecificationsContent.ProductsAndServices <> SpecificationsContent.Ref.Owner
	|	AND SpecificationsContent.ContentRowType <> VALUE(Enum.SpecificationContentRowTypes.Expense)
	|
	|INDEX BY
	|	ProductsAndServicesNode,
	|	CharacteristicNode,
	|	SpecificationNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PlannedCostsOnOutput.Company,
	|	PlannedCostsOnOutput.Division,
	|	PlannedCostsOnOutput.Products,
	|	PlannedCostsOnOutput.ProductCharacteristic,
	|	PlannedCostsOnOutput.BatchProducts,
	|	PlannedCostsOnOutput.CustomerOrder,
	|	PlannedCostsOnOutput.SpecificationProductRelease,
	|	PlannedCostsOnOutput.ProductionSpecification,
	|	PlannedCostsOnOutput.QuantityProductRelease,
	|	PlannedCostsOnOutput.ProductsAndServices AS ProductsAndServices,
	|	PlannedCostsOnOutput.Characteristic AS Characteristic,
	|	PlannedCostsOnOutput.Quantity,
	|	PlannedCostsOnOutput.Specification AS Specification,
	|	PlannedCostsOnOutput.ContentRowType
	|INTO TemporaryTablePlannedCosts
	|FROM
	|	&TablePlanCostsOnOutput AS PlannedCostsOnOutput
	|
	|INDEX BY
	|	ProductsAndServices,
	|	Characteristic,
	|	Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PlannedCostsOnOutput.Company,
	|	PlannedCostsOnOutput.Division,
	|	PlannedCostsOnOutput.Products,
	|	PlannedCostsOnOutput.ProductCharacteristic,
	|	PlannedCostsOnOutput.BatchProducts,
	|	PlannedCostsOnOutput.CustomerOrder,
	|	PlannedCostsOnOutput.SpecificationProductRelease,
	|	PlannedCostsOnOutput.ProductionSpecification,
	|	PlannedCostsOnOutput.QuantityProductRelease,
	|	ISNULL(CompositionNodes.ProductsAndServices, PlannedCostsOnOutput.ProductsAndServices) AS ProductsAndServices,
	|	ISNULL(CompositionNodes.Characteristic, PlannedCostsOnOutput.Characteristic) AS Characteristic,
	|	CASE
	|		WHEN PlannedCostsOnOutput.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Node)
	|			THEN CASE
	|					WHEN ISNULL(PlannedCostsOnOutput.Quantity, 0) = 0
	|						THEN 1
	|					ELSE PlannedCostsOnOutput.Quantity
	|				END * CompositionNodes.Quantity
	|		ELSE PlannedCostsOnOutput.Quantity
	|	END AS Quantity,
	|	ISNULL(CompositionNodes.Specification, PlannedCostsOnOutput.Specification) AS Specification,
	|	ISNULL(CompositionNodes.ContentRowType, PlannedCostsOnOutput.ContentRowType) AS ContentRowType,
	|	CASE
	|		WHEN PlannedCostsOnOutput.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Node)
	|				AND CompositionNodes.ProductsAndServicesNode IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Explosion
	|INTO TemporaryTableContentRelease
	|FROM
	|	TemporaryTablePlannedCosts AS PlannedCostsOnOutput
	|		LEFT JOIN TemporaryTableCompositionNodes AS CompositionNodes
	|		ON PlannedCostsOnOutput.ProductsAndServices = CompositionNodes.ProductsAndServicesNode
	|			AND PlannedCostsOnOutput.Characteristic = CompositionNodes.CharacteristicNode
	|			AND PlannedCostsOnOutput.Specification = CompositionNodes.SpecificationNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompositionOutput.Company,
	|	CompositionOutput.Division,
	|	CompositionOutput.Products,
	|	CompositionOutput.ProductCharacteristic,
	|	CompositionOutput.BatchProducts,
	|	CompositionOutput.CustomerOrder,
	|	CompositionOutput.SpecificationProductRelease,
	|	CompositionOutput.ProductionSpecification,
	|	CompositionOutput.QuantityProductRelease,
	|	CompositionOutput.ProductsAndServices,
	|	CompositionOutput.Characteristic,
	|	CompositionOutput.Quantity,
	|	CompositionOutput.Specification,
	|	CompositionOutput.ContentRowType
	|FROM
	|	TemporaryTableContentRelease AS CompositionOutput
	|WHERE
	|	CompositionOutput.Explosion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CompositionOutput.ProductsAndServices AS ProductsAndServicesNode,
	|	CompositionOutput.Characteristic AS CharacteristicNode,
	|	CompositionOutput.Specification AS SpecificationNode
	|FROM
	|	TemporaryTableContentRelease AS CompositionOutput
	|WHERE
	|	CompositionOutput.ContentRowType = VALUE(Enum.SpecificationContentRowTypes.Node)";
	
	Result = Query.ExecuteBatch();
	
	TablePlanCostsOnOutput = Result[4].Unload();
	TableNodeSpecificationToExplosion = Result[5].Unload();
	
EndProcedure

Procedure CalculateCostPricePlannedCostsOnOutput(TablePlanCostsOnOutput)
	
	BeginOfPeriod = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	EndOfPeriod  = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	
	Query = New Query;
	Query.SetParameter("TablePlanCostsOnOutput", TablePlanCostsOnOutput);
	Query.SetParameter("BeginOfPeriod", ?(BeginOfPeriod = Undefined OR Not BeginOfPeriod.Use, Date(1,1,1), BeginOfPeriod.Value));
	Query.SetParameter("EndOfPeriod",  ?(EndOfPeriod = Undefined OR Not EndOfPeriod.Use, Date(3999,12,31), EndOfPeriod.Value));
	
	Query.Text = 
	"SELECT
	|	PlannedCostsOnOutput.Company AS Company,
	|	PlannedCostsOnOutput.Division AS Division,
	|	PlannedCostsOnOutput.Products AS Products,
	|	PlannedCostsOnOutput.ProductCharacteristic AS ProductCharacteristic,
	|	PlannedCostsOnOutput.BatchProducts AS BatchProducts,
	|	PlannedCostsOnOutput.CustomerOrder AS CustomerOrder,
	|	PlannedCostsOnOutput.SpecificationProductRelease AS SpecificationProductRelease,
	|	PlannedCostsOnOutput.ProductionSpecification AS ProductionSpecification,
	|	PlannedCostsOnOutput.QuantityProductRelease AS QuantityProductRelease,
	|	PlannedCostsOnOutput.ProductsAndServices AS ProductsAndServices,
	|	PlannedCostsOnOutput.Characteristic AS Characteristic,
	|	PlannedCostsOnOutput.Quantity AS Quantity,
	|	PlannedCostsOnOutput.ContentRowType
	|INTO TemporaryTablePlannedCostsForProduction
	|FROM
	|	&TablePlanCostsOnOutput AS PlannedCostsOnOutput
	|WHERE
	|	PlannedCostsOnOutput.ContentRowType <> VALUE(Enum.SpecificationContentRowTypes.Node)
	|			AND PlannedCostsOnOutput.ContentRowType <> VALUE(Enum.SpecificationContentRowTypes.Expense)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnitCorr AS Division,
	|	Inventory.ProductsAndServicesCorr AS Products,
	|	Inventory.CharacteristicCorr AS ProductCharacteristic,
	|	Inventory.BatchCorr AS BatchProducts,
	|	Inventory.CustomerCorrOrder AS CustomerOrder,
	|	Inventory.SpecificationCorr AS ProductionSpecification,
	|	Inventory.ProductsAndServices AS ProductsAndServices,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Specification AS Specification,
	|	SUM(Inventory.Amount) AS Amount,
	|	SUM(Inventory.Quantity) AS Quantity
	|INTO TemporaryTableCostForProduction
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Inventory.ProductionExpenses
	|	AND Inventory.Period between &BeginOfPeriod AND &EndOfPeriod
	|	AND Not Inventory.ProductsAndServices = VALUE(Catalog.ProductsAndServices.EmptyRef)
	|
	|GROUP BY
	|	Inventory.SpecificationCorr,
	|	Inventory.Characteristic,
	|	Inventory.StructuralUnitCorr,
	|	Inventory.ProductsAndServicesCorr,
	|	Inventory.BatchCorr,
	|	Inventory.ProductsAndServices,
	|	Inventory.CustomerCorrOrder,
	|	Inventory.CharacteristicCorr,
	|	Inventory.Company,
	|	Inventory.Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PlannedCostsOnOutput.Company AS Company,
	|	PlannedCostsOnOutput.Division AS Division,
	|	PlannedCostsOnOutput.Products AS Products,
	|	PlannedCostsOnOutput.ProductCharacteristic AS ProductCharacteristic,
	|	PlannedCostsOnOutput.BatchProducts AS BatchProducts,
	|	PlannedCostsOnOutput.CustomerOrder AS CustomerOrder,
	|	PlannedCostsOnOutput.SpecificationProductRelease AS ProductionSpecification,
	|	PlannedCostsOnOutput.ProductsAndServices AS ProductsAndServices,
	|	PlannedCostsOnOutput.Characteristic AS Characteristic,
	|	ActualCostsOnOutput.Specification AS Specification,
	|	PlannedCostsOnOutput.Quantity AS CostsQuantityPlan,
	|	CASE
	|		WHEN ISNULL(ActualCostsOnOutput.Amount, 0) = 0
	|				OR ISNULL(ActualCostsOnOutput.Quantity, 0) = 0
	|			THEN 0
	|		ELSE PlannedCostsOnOutput.Quantity * (ActualCostsOnOutput.Amount / ActualCostsOnOutput.Quantity)
	|	END AS ExpensesCostPlan
	|FROM
	|	TemporaryTablePlannedCostsForProduction AS PlannedCostsOnOutput
	|		LEFT JOIN TemporaryTableCostForProduction AS ActualCostsOnOutput
	|		ON PlannedCostsOnOutput.Company = ActualCostsOnOutput.Company
	|			AND PlannedCostsOnOutput.Division = ActualCostsOnOutput.Division
	|			AND PlannedCostsOnOutput.Products = ActualCostsOnOutput.Products
	|			AND PlannedCostsOnOutput.ProductCharacteristic = ActualCostsOnOutput.ProductCharacteristic
	|			AND PlannedCostsOnOutput.BatchProducts = ActualCostsOnOutput.BatchProducts
	|			AND PlannedCostsOnOutput.CustomerOrder = ActualCostsOnOutput.CustomerOrder
	|			AND PlannedCostsOnOutput.SpecificationProductRelease = ActualCostsOnOutput.ProductionSpecification
	|			AND PlannedCostsOnOutput.ProductsAndServices = ActualCostsOnOutput.ProductsAndServices
	|			AND PlannedCostsOnOutput.Characteristic = ActualCostsOnOutput.Characteristic";
	
	TablePlanCostsOnOutput = Query.Execute().Unload();
	
EndProcedure

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	TitleOutput = False;
	Title = "Output net cost plan/actual analysis";
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ItmPeriod"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriod.Use
			AND ValueIsFilled(ParameterPeriod.Value) Then
			
			BeginOfPeriod = ParameterPeriod.Value.StartDate;
			EndOfPeriod  = ParameterPeriod.Value.EndDate;
		EndIf;
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined
		AND ParameterOutputTitle.Use Then
		
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined
		AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("BeginOfPeriod"            , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"             , EndOfPeriod);
	ReportParameters.Insert("TitleOutput"        , TitleOutput);
	ReportParameters.Insert("Title"                , Title);
	ReportParameters.Insert("ReportId"      , "OutputNetCostPlanActualAnalysis");
	ReportParameters.Insert("ReportSettings", ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf