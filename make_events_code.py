import country_converter as coco
import pandas as pd
import os

#https://www.kaggle.com/datasets/iamsouravbanerjee/world-population-dataset

def make_population_df():
    df = pd.read_csv('utils/world_population.csv')
    df['country'] = coco.convert(names=df['CCA3'],to='ISO2')
    df_events = df[['Country/Territory','CCA3','2022 Population','country']]
    df_events.columns = ['country_name','iso3', 'pop', 'country']
    df_events.to_csv('utils/population_data.csv',index=False)

def df_events_to_stata(keyword_dict,regs):
    """keyword_dict: a dictionary for your keyword and event dates if there's different event_dates"""
    df = pd.read_csv('utils/population_data.csv')
    df['country'] = df['country'].astype(str).replace('nan','NA') ## Namibia
    world_data = {'country_name': 'world', 'iso3': '','country': '', 'pop': sum(df['pop'])}
    df = df._append(world_data,ignore_index=True)
    #df['country'] = df.index + 1 #countries as integer for stata
    for k,v in keyword_dict.items():
        col_name = f'date_event_{k}'
        event_date = pd.to_datetime(v)
        df[col_name] = event_date
    output_df = df[df['country'].isin(regs)].reset_index(drop=True)
    output_df.country = output_df.index + 1
    output_df.to_stata('data/EventsData.dta')


def make_stata_file(var_names,regs):
    current_dir = os.path.join(os.getcwd(),'data')
    regs = ['world' if x == '' else x for x in regs]
    var_names = ' '.join([x.replace(' ', '_') for x in var_names])
    clean_vars = var_names.replace(' ','_')
    regions = ' '.join(regs)
    first_region,regions1 = regs[0],' '.join(regs[1:])
    with open('codes/StataMerge_Template.do', 'r') as inf:
        file_data = inf.read()
    file_data = file_data.replace('VARLIST', f'"{var_names}"')
    file_data = file_data.replace('INPUTDATADIR', f'"{current_dir}"')
    file_data = file_data.replace('REGLIST', f'"{regions}"')
    file_data = file_data.replace('REG1LIST', f'"{regions1}"')
    file_data = file_data.replace('FIRSTREG', f'{first_region}')
    file_data = file_data.replace('EVENTSDTAFILE', f'{clean_vars}')
    output_filename = f'codes/StataMerge_{clean_vars}.do'
    with open(output_filename,'w') as of:
        of.write(file_data)

def make_stata_analysis_file(var_names):
    with open('codes/StataAnalysis_Template.do', 'r') as inf:
        file_data = inf.read()
    vars_cleaned = [x.replace(' ', '_') for x in var_names]
    var_names = ' '.join(vars_cleaned)
    file_data = file_data.replace('VARLIST', f'"{var_names}"')
    current_dir = os.path.join(os.getcwd(),'data')
    results_dir = os.path.join(os.getcwd(),'results')
    file_data = file_data.replace('INPUTDATADIR', f'"{current_dir}"')
    file_data = file_data.replace('RESULTSDIR', f'"{results_dir}"')
    additional_dir = os.path.join(results_dir,'All_figures_and_tables')
    if not os.path.exists(additional_dir):
        os.mkdir(additional_dir)
    for i,var_name in enumerate(vars_cleaned):
        var_result_dir = os.path.join(results_dir, var_name)
        if not os.path.exists(var_result_dir):
            os.mkdir(var_result_dir)
        file_data = file_data.replace(f'VARNAME{i+1}', var_name)
    clean_vars = var_names.replace(' ','_')
    output_filename = f'codes/StataAnalysis_{clean_vars}.do'
    with open(output_filename,'w') as of:
        of.write(file_data)


def df_events_to_stata_same_date(var_names,regs,event_date):
    """var_names:  list of variable names to use
        regs: Regions used
        event_date: the event date"""
    vars_cleaned = [x.replace(' ', '_') for x in var_names]
    df = pd.read_csv('utils/population_data.csv')
    df['country'] = df['country'].astype(str).replace('nan','NA') ## Namibia
    world_data = {'country_name': 'world', 'iso3': 'world','country': 'world', 'pop': sum(df['pop'])}
    df = df._append(world_data,ignore_index=True)
    df['date_event_ann'] = event_date
    output_df = df[df['country'].isin(regs)].reset_index(drop=True)
    output_df.to_stata(f'data/EventsData_{'_'.join(vars_cleaned)}.dta')
    make_stata_file(var_names,regs)
    make_stata_analysis_file(var_names)




