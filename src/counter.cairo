#[starknet::interface]
trait ICounter<T> {
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T);
}

#[starknet::contract]
mod counter_contract {
    use kill_switch::IKillSwitchDispatcherTrait;
    use starknet::ContractAddress;
    use kill_switch::IKillSwitchDispatcher;
    use openzeppelin::access::ownable::OwnableComponent;
    use super::{ICounter, ICounterDispatcher, ICounterDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,

        
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }   

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: IKillSwitchDispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage


    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        value: u32,
    } 

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, initial_kill_switch_address: ContractAddress, initial_owner: ContractAddress) {

        let dispatcher = IKillSwitchDispatcher { contract_address: initial_kill_switch_address };
        self.kill_switch.write(dispatcher);


        self.counter.write(initial_value);
        self.ownable.initializer(initial_owner);
    }

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ICounterImp of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let kill_switch = self.kill_switch.read();
            if(kill_switch.is_active() == false){
                self.counter.write(self.counter.read() + 1);
                self.emit(CounterIncreased { value: self.counter.read() });
            }
            
            assert!(!kill_switch.is_active(), "Kill Switch is active");
            
        }
    }
}
