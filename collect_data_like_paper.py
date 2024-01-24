from collector import DataCollectorSimple, ProxyItem
from make_events_code import df_events_to_stata_same_date

def collect_like_paper():
    proxy = ProxyItem()
    regs = ['US', 'GB', 'ES', 'PL', 'FR', 'DE', 'IT', '']
    simple = DataCollectorSimple(['Coca Cola', 'Pepsi'], regs, '2021-06-14',proxy=proxy)
    for i in range(len(simple.kw_list)):
        simple.loop_regions(simple.kw_list[i],i)
    df_events_to_stata_same_date(['Coca Cola', 'Pepsi'], ['US', 'GB', 'ES', 'PL', 'FR', 'DE', 'IT', 'world'], '2021-06-14')
    simple = DataCollectorSimple(['Budweiser','Heineken'], regs, '2021-06-15',proxy=proxy)
    for i in range(len(simple.kw_list)):
        simple.loop_regions(simple.kw_list[i],i)
    df_events_to_stata_same_date(['Coca Cola', 'Pepsi'], ['US', 'GB', 'ES', 'PL', 'FR', 'DE', 'IT', 'world'], '2021-06-15')
    proxy.client.disconnect()


collect_like_paper()