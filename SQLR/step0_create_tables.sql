-- Create an empty table to be filled with the training set.
DROP TABLE IF EXISTS [dbo].[News_Train];
CREATE TABLE [dbo].[News_Train](
	    [Label] [int] NOT NULL,
	    [Subject] [varchar] (max) NULL, 
		[Text] [varchar] (max) NULL,
		[Id] [int] NOT NULL
		);

-- Create an empty table to be filled with the testing set.
DROP TABLE IF EXISTS [dbo].[News_Test];
CREATE TABLE [dbo].[News_Test](
	    [Label] [int] NOT NULL,
	    [Subject] [varchar] (max) NULL, 
		[Text] [varchar] (max) NULL,
		[Id] [int] NOT NULL
		);

-- Create an empty table to be filled with an additional data set to be scored.
DROP TABLE IF EXISTS [dbo].[News_To_Score];
CREATE TABLE [dbo].[News_To_Score](
	    [Label] [int] NULL,
	    [Subject] [varchar] (max) NULL, 
		[Text] [varchar] (max) NULL,
		[Id] [int] NOT NULL
		);

-- Create an empty table to be filled with the correspondance between the label numbers and names.
DROP TABLE IF EXISTS [dbo].[Label_Names];
CREATE TABLE [dbo].[Label_Names](
	    [Label] [int] NOT NULL,
	    [LabelNames] [varchar] (30) NULL);


-- Create an empty table to be filled with the trained models.
DROP TABLE if exists [dbo].[Model]
CREATE TABLE [dbo].[Model](
		[id] [varchar](200) NOT NULL, 
	    [value] [varbinary](max), 
		CONSTRAINT unique_id UNIQUE(id));


-- Create an empty table to be filled with the Metrics.
DROP TABLE if exists [dbo].[Metrics]
CREATE TABLE [dbo].[Metrics](
		[id] [varchar](30) NOT NULL,
		[avg_accuracy_micro] [float] NULL,
		[avg_accuracy_macro] [float] NULL,
		CONSTRAINT unique_id2 UNIQUE(id));
		
